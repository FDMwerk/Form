import UIKit
import WebKit
import UniformTypeIdentifiers

@main
final class MobileApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let viewer = MobileViewerController()
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = viewer
        window?.makeKeyAndVisible()
        if let url = options?[.url] as? URL { viewer.enqueue([url]) }
        return true
    }
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard MobileFilePolicy.accepts(url) else { return false }
        viewer.enqueue([url]); return true
    }
}

/// These are model imports, never arbitrary remote webpage downloads.
enum MobileFilePolicy {
    static let extensions = ["stl", "step", "stp", "iges", "igs", "brep", "brp", "obj", "ply", "3mf", "glb", "gltf"]
    static let maxBytes = 100 * 1024 * 1024
    static func accepts(_ url: URL) -> Bool { url.isFileURL && extensions.contains(url.pathExtension.lowercased()) }
}

final class MobileViewerController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, UIDocumentPickerDelegate {
    private(set) var web: WKWebView!
    private(set) var ready = false
    private var importing = false
    private var pending: [URL] = []
    private var sources: [String: URL] = [:]
    private let reader = DispatchQueue(label: "de.fdmwerk.form.mobile.import", qos: .userInitiated)
    private let preferenceKey = "FormMobileViewportPreferences"
    private let sessionDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("Form-" + UUID().uuidString, isDirectory: true)
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: "native")
        for (name, ext) in [("viewport", "css"), ("viewport", "js")] {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext), let content = try? String(contentsOf: url) else { continue }
            let script: String
            if ext == "css", let data = try? JSONSerialization.data(withJSONObject: [content]), let literal = String(data: data, encoding: .utf8) {
                script = "const mobileStyle=document.createElement('style');mobileStyle.textContent=\(literal)[0];document.head.appendChild(mobileStyle);"
            } else { script = content }
            configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = self
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        view.addSubview(web)
        web.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") else { showError("Viewer resources are missing."); return }
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    func enqueue(_ urls: [URL]) {
        pending.append(contentsOf: urls)
        if isViewLoaded { drain() }
    }
    private func drain() {
        guard ready, !importing, !pending.isEmpty else { return }
        let url = pending.removeFirst()
        guard MobileFilePolicy.accepts(url) else { showError("Unsupported 3D file."); drain(); return }
        importing = true
        let destination = sessionDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true).appendingPathComponent(url.lastPathComponent)
        reader.async {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                var coordinatedError: NSError?
                var readResult: Result<Data, Error>?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatedError) { coordinated in
                    readResult = Result {
                        let size = try coordinated.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                        guard size.isRegularFile == true, (size.fileSize ?? Int.max) <= MobileFilePolicy.maxBytes else { throw CocoaError(.fileReadTooLarge) }
                        let data = try Data(contentsOf: coordinated)
                        guard data.count <= MobileFilePolicy.maxBytes else { throw CocoaError(.fileReadTooLarge) }
                        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try data.write(to: destination, options: .atomic)
                        return data
                    }
                }
                if let error = coordinatedError { throw error }
                guard let result = readResult else { throw CocoaError(.fileReadUnknown) }
                let data = try result.get()
                DispatchQueue.main.async {
                    let id = UUID().uuidString
                    self.web.callAsyncJavaScript("return await window.openModel(name, bytes, sourceID)", arguments: ["name": url.lastPathComponent, "bytes": data.base64EncodedString(), "sourceID": id], in: nil, in: .page) { result in
                        if case .success(let value) = result, (value as? Bool) == true { self.sources[id] = destination }
                        else { try? FileManager.default.removeItem(at: destination.deletingLastPathComponent()) }
                        self.importing = false; self.drain()
                    }
                }
            } catch {
                DispatchQueue.main.async { self.importing = false; self.showError(error.localizedDescription); self.drain() }
            }
        }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.webView === web, message.frameInfo.request.url?.isFileURL == true else { return }
        if let object = message.body as? [String: Any] {
            if object["type"] as? String == "viewportPreferences", let value = object["value"] as? [String: Any], JSONSerialization.isValidJSONObject(value) { UserDefaults.standard.set(value, forKey: preferenceKey) }
            if object["type"] as? String == "saveScreenshot", let png = object["png"] as? String, png.count < 64 * 1024 * 1024, let data = Data(base64Encoded: png), let image = UIImage(data: data) { share([image]) }
            return
        }
        switch message.body as? String {
        case "ready":
            guard !ready else { return }
            let prefs = UserDefaults.standard.dictionary(forKey: preferenceKey) ?? [:]
            web.callAsyncJavaScript("window.applySystemLanguages(languages);window.applyViewportSettings(preferences);window.applyNativeCapabilities({externalSliceEstimate:false,blenderImport:false,donations:false});window.applyPrintSoftware([])", arguments: ["languages": Locale.preferredLanguages, "preferences": prefs], in: nil, in: .page) { result in
                guard case .success = result else { self.showError("Viewer initialization failed."); return }
                self.ready = true; self.drain()
            }
        case "open":
            let types = MobileFilePolicy.extensions.compactMap { UTType(filenameExtension: $0) }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.allowsMultipleSelection = true; picker.delegate = self
            if presentedViewController == nil { present(picker, animated: true) }
        case "openWith", "openInSlicer":
            web.callAsyncJavaScript("return window.selectedSourceID()", arguments: [:], in: nil, in: .page) { result in
                guard case .success(let value) = result, let id = value as? String, let url = self.sources[id] else { self.showError("Select a file to share."); return }
                self.share([url])
            }
        case "legal":
            if let url = Bundle.main.url(forResource: "legal", withExtension: "html", subdirectory: "Web") {
                let controller = UIViewController(); let legal = WKWebView(); controller.view = legal
                legal.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                present(controller, animated: true)
            }
        case "feedback":
            if let url = URL(string: "https://github.com/FDMwerk/Form/issues") { UIApplication.shared.open(url) }
        default: break
        }
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { enqueue(urls) }
    private func share(_ items: [Any]) {
        guard presentedViewController == nil else { return }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = view
        controller.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: 44, width: 1, height: 1)
        present(controller, animated: true)
    }
    private func showError(_ message: String) {
        guard isViewLoaded, presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Form", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        // Only bundled content is allowed to run with access to the native bridge.
        if url.isFileURL, let root = Bundle.main.resourceURL?.standardizedFileURL.path, url.standardizedFileURL.path.hasPrefix(root + "/") { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false; importing = false
        showError("The viewer ran out of resources. Reopen your models after restarting Form.")
    }
}
