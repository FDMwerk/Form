import AppKit
import WebKit
import UniformTypeIdentifiers

/// A narrow titlebar strip keeps viewport gestures available below the window edge.
private final class FormWindowDragView: NSView {
 override var mouseDownCanMoveWindow: Bool { true }
 override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
 private let fileReader = DispatchQueue(label: "de.fdmwerk.form.file-reader", qos: .userInitiated)
 private let preferencesKey = "FormViewportPreferences"
 private var webRoot: URL?
 private var window: NSWindow!
 private var web: WKWebView!
 private var ready = false
 private var activeLanguage = "en"
 private var nativeCatalogs: [String: [String: String]] = [:]
 private func text(_ key: String) -> String { nativeCatalogs[activeLanguage]?[key] ?? nativeCatalogs["en"]?[key] ?? key }
 private func updateLanguage(_ preference: String) {
  activeLanguage = FormLanguagePolicy.resolve(preference, preferredLanguages: Locale.preferredLanguages, available: Array(nativeCatalogs.keys))
  configureMenus()
  legalWindow?.title = text("legal")
 }
 private func loadNativeCatalogs() {
  if let directory = Bundle.main.url(forResource: "locales", withExtension: nil, subdirectory: "Web"),
     let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
   for url in urls where url.pathExtension == "json" {
    if let data = try? Data(contentsOf: url), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let native = object["native"] as? [String: String] { nativeCatalogs[url.deletingPathExtension().lastPathComponent] = native }
   }
  }
 }
 private lazy var imports = FormImportQueue(
  read: { [unowned self] url, completion in self.readFile(url, completion: completion) },
  importData: { [unowned self] url, data, completion in
   self.web.callAsyncJavaScript("await window.openModel(name, bytes)", arguments: ["name": url.lastPathComponent, "bytes": data.base64EncodedString()], in: nil, in: .page) { result in
    completion(result.map { ($0 as? Bool) == true })
   }
  },
  didImport: { [unowned self] url in
   self.window.representedURL = url
   NSDocumentController.shared.noteNewRecentDocumentURL(url)
  },
  presentError: { [unowned self] error, dismissed in self.presentImportError(error, dismissed: dismissed) }
 )
 private var legalWindow: NSWindow?

 static func main() {
  let app = NSApplication.shared
  let delegate = AppDelegate()
  app.delegate = delegate
  app.setActivationPolicy(.regular)
  withExtendedLifetime(delegate) { app.run() }
 }

 func applicationDidFinishLaunching(_ notification: Notification) {
  let config = WKWebViewConfiguration()
  config.userContentController.add(self, name: "native")
  // A viewer does not need persistent website cookies or browser history.
  config.websiteDataStore = .nonPersistent()
  web = WKWebView(frame: .zero, configuration: config)
  web.navigationDelegate = self
  window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
  window.title = "Form"
  window.titleVisibility = .hidden
  window.titlebarAppearsTransparent = true
  window.minSize = NSSize(width: 1040, height: 600)
  window.isMovable = true
  let content = NSView(frame: window.contentRect(forFrameRect: window.frame))
  web.frame = content.bounds
  web.autoresizingMask = [.width, .height]
  content.addSubview(web)
  let dragStrip = FormWindowDragView(frame: NSRect(x: 80, y: content.bounds.height - 28, width: content.bounds.width - 80, height: 28))
  dragStrip.autoresizingMask = [.width, .minYMargin]
  content.addSubview(dragStrip)
  window.contentView = content
  window.center()
  window.makeKeyAndOrderFront(nil)
  loadNativeCatalogs()
  updateLanguage(FormLanguagePolicy.preference(UserDefaults.standard.dictionary(forKey: preferencesKey)?["language"]))
  guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") else {
   let alert = NSAlert()
   alert.messageText = text("incompleteTitle")
   alert.informativeText = text("incompleteBody")
   alert.runModal()
   NSApplication.shared.terminate(nil)
   return
  }
  webRoot = url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
  web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
  NSApplication.shared.activate(ignoringOtherApps: true)
 }

 private func configureMenus() {
  let menu = NSMenu()
  let appItem = NSMenuItem()
  menu.addItem(appItem)
  let appMenu = NSMenu()
  appMenu.addItem(withTitle: text("about"), action: #selector(about), keyEquivalent: "")
  appMenu.addItem(withTitle: text("settings"), action: #selector(showSettings), keyEquivalent: ",")
  appMenu.addItem(withTitle: text("legal"), action: #selector(showLegal), keyEquivalent: "")
  appMenu.addItem(.separator())
  appMenu.addItem(withTitle: text("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
  appItem.submenu = appMenu
  let fileItem = NSMenuItem()
  menu.addItem(fileItem)
  let fileMenu = NSMenu(title: text("file"))
  fileMenu.addItem(withTitle: text("open"), action: #selector(openPanel), keyEquivalent: "o")
  let screenshotItem = fileMenu.addItem(withTitle: text("saveScreenshot"), action: #selector(captureScreenshot), keyEquivalent: "s")
  screenshotItem.keyEquivalentModifierMask = [.command, .shift]
  fileItem.submenu = fileMenu
  let editItem = NSMenuItem()
  menu.addItem(editItem)
  let edit = NSMenu(title: text("edit"))
  edit.addItem(withTitle: text("copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
  edit.addItem(withTitle: text("paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
  edit.addItem(withTitle: text("selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
  editItem.submenu = edit
  NSApplication.shared.mainMenu = menu
 }

 @objc private func about() {
  let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Preview"
  NSApplication.shared.orderFrontStandardAboutPanel(options: [
   .applicationName: "Form",
   .applicationVersion: version,
   .credits: NSAttributedString(string: "\(text("aboutDescription"))\nsupport@fdmwerk.de\nThree.js · Lucide · Open CASCADE / occt-import-js\n\(text("sourceLabel")): github.com/FDMwerk/Form")
  ])
 }

 @objc private func showSettings() {
  guard ready else { return }
  web.evaluateJavaScript("window.showSettings()", completionHandler: nil)
 }

 @objc private func showLegal() {
  if let existing = legalWindow { existing.makeKeyAndOrderFront(nil); return }
  guard let url = Bundle.main.url(forResource: "legal", withExtension: "html", subdirectory: "Web") else { return }
  let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 650, height: 650), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
  w.title = text("legal")
  w.isReleasedWhenClosed = false
  let configuration = WKWebViewConfiguration()
  configuration.websiteDataStore = .nonPersistent()
  let view = WKWebView(frame: .zero, configuration: configuration)
  view.navigationDelegate = self
  w.contentView = view
  view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
  w.center()
  w.makeKeyAndOrderFront(nil)
  legalWindow = w
 }

 @objc private func captureScreenshot() {
  guard ready, window.attachedSheet == nil else { return }
  web.evaluateJavaScript("window.captureScreenshot()", completionHandler: nil)
 }

 private func saveScreenshot(_ value: Any?) {
  guard window.attachedSheet == nil else { return }
  do {
   let data = try FormScreenshotPolicy.decode(value)
   let panel = NSSavePanel()
   panel.title = text("saveScreenshot")
   panel.nameFieldStringValue = "Form.png"
   panel.allowedContentTypes = [.png]
   panel.canCreateDirectories = true
   panel.beginSheetModal(for: window) { response in
    guard response == .OK, let url = panel.url else { return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do { try data.write(to: url, options: .atomic) }
    catch { self.presentScreenshotError() }
   }
  } catch { presentScreenshotError() }
 }

 private func presentScreenshotError() {
  let alert = NSAlert()
  alert.messageText = text("screenshotError")
  alert.addButton(withTitle: text("ok"))
  alert.beginSheetModal(for: window, completionHandler: nil)
 }

 @objc private func openPanel() {
  guard window.attachedSheet == nil else { return }
  let panel = NSOpenPanel()
  panel.title = text("open")
  panel.allowedContentTypes = FormImportPolicy.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
  panel.allowsOtherFileTypes = false
  panel.allowsMultipleSelection = true
  panel.canChooseDirectories = false
  panel.beginSheetModal(for: window) { response in
   if response == .OK { for url in panel.urls { self.load(url) } }
  }
 }

 func application(_ sender: NSApplication, openFiles filenames: [String]) {
  for path in filenames { load(URL(fileURLWithPath: path)) }
  sender.reply(toOpenOrPrint: .success)
 }

 private func load(_ url: URL) { imports.enqueue(url) }

 private func readFile(_ url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
  let scoped = url.startAccessingSecurityScopedResource()
  fileReader.async {
   let result = Result { try FormImportPolicy.read(url) }
   if scoped { url.stopAccessingSecurityScopedResource() }
   DispatchQueue.main.async { completion(result) }
  }
 }

 private func presentImportError(_ error: Error, dismissed: @escaping () -> Void) {
  if window.attachedSheet != nil {
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.presentImportError(error, dismissed: dismissed) }
   return
  }
  let alert = NSAlert()
  alert.messageText = text("importErrorTitle")
  let nativeError = error as NSError
  let keys = [1: "importUnsupported", 2: "importDirectory", 3: "importTooLarge", 4: "importEmpty"]
  alert.informativeText = text(nativeError.domain == "Form.Import" ? (keys[nativeError.code] ?? "importReadFailed") : (nativeError.domain == WKError.errorDomain ? "importBridgeFailed" : "importReadFailed"))
  alert.addButton(withTitle: text("ok"))
  alert.beginSheetModal(for: window) { _ in dismissed() }
 }

 func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
  guard FormBridgePolicy.acceptsMessage(source: message.frameInfo.request.url, root: webRoot,
        isMainFrame: message.frameInfo.isMainFrame, isViewerWebView: message.webView === web) else { return }
  if let data = message.body as? [String: Any], data["type"] as? String == "saveScreenshot" {
   saveScreenshot(data["png"])
   return
  }
  if let data = message.body as? [String: Any], data["type"] as? String == "viewportPreferences",
     let value = data["value"] as? [String: Any], let clean = FormPreferencePolicy.sanitize(value) {
   UserDefaults.standard.set(clean, forKey: preferencesKey)
   updateLanguage(clean["language"] as? String ?? "system")
   return
  }
  guard let command = message.body as? String else { return }
  switch command {
  case "ready":
   guard !ready else { return }
   ready = true
   let completeStartup = { self.imports.setReady() }
   web.callAsyncJavaScript("window.applySystemLanguages(languages)", arguments: ["languages": Locale.preferredLanguages], in: nil, in: .page) { _ in
    if let saved = UserDefaults.standard.dictionary(forKey: self.preferencesKey), let clean = FormPreferencePolicy.sanitize(saved) {
     self.web.callAsyncJavaScript("window.applyViewportSettings(value)", arguments: ["value": clean], in: nil, in: .page) { _ in completeStartup() }
    } else { completeStartup() }
   }
  case "open": openPanel()
  case "legal": showLegal()
  default: break
  }
 }

 func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
  guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
  if FormBridgePolicy.isBundledWebURL(url, root: webRoot) { decisionHandler(.allow); return }
  // Explicitly clicked documentation/support links open outside the local viewer.
  if navigationAction.navigationType == .linkActivated,
     url.scheme == "https" || url.scheme == "mailto" {
   NSWorkspace.shared.open(url)
  }
  decisionHandler(.cancel)
 }

 func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
