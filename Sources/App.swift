import AppKit
import WebKit
import UniformTypeIdentifiers

/// A narrow titlebar strip keeps viewport gestures available below the window edge.
private final class FormWindowDragView: NSView {
 override var mouseDownCanMoveWindow: Bool { true }
 override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

private final class FormExternalMenuTarget: NSObject {
 let app: FormExternalApplication
 let file: URL
 init(app: FormExternalApplication, file: URL) { self.app = app; self.file = file }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
 private let fileReader = DispatchQueue(label: "de.fdmwerk.form.file-reader", qos: .userInitiated)
 private let preferencesKey = "FormViewportPreferences"
 private var webRoot: URL?
 private var window: NSWindow!
 private var web: WKWebView!
 private var ready = false
 private let sourceRegistry = FormSourceRegistry()
 #if !FORM_APP_STORE
 private let sliceWorker = DispatchQueue(label: "de.fdmwerk.form.slice-estimate", qos: .userInitiated)
 private var sliceControl: FormBoundedProcess?
 #endif
 private var sliceRequestID: String?
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
   let sourceID = UUID().uuidString
   self.web.callAsyncJavaScript("return await window.openModel(name, bytes, sourceID)", arguments: ["name": url.lastPathComponent, "bytes": data.base64EncodedString(), "sourceID": sourceID], in: nil, in: .page) { result in
    let imported = result.map { ($0 as? Bool) == true }
    if case .success(true) = imported { self.sourceRegistry.record(sourceID, url: url, imported: true) }
    completion(imported)
   }
  },
  didImport: { [unowned self] url in
   self.window.representedURL = url
   NSDocumentController.shared.noteNewRecentDocumentURL(url)
  },
  presentError: { [unowned self] error, dismissed in self.presentImportError(error, dismissed: dismissed) }
 )
 private var legalWindow: NSWindow?

 private static func bundledApplicationIcon(in bundle: Bundle = .main) -> NSImage? {
  let candidates = [
   bundle.url(forResource: "app-icon", withExtension: "png", subdirectory: "Web"),
   bundle.url(forResource: "AppIcon", withExtension: "icns")
  ]
  for case let url? in candidates {
   if let image = NSImage(contentsOf: url), image.isValid { return image }
  }
  return nil
 }

 static func main() {
  let app = NSApplication.shared
  // Set our bundled artwork before activating the Dock presence.
  if let icon = bundledApplicationIcon() { app.applicationIconImage = icon }
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
  let visibleSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1320, height: 860)
  let initialSize = NSSize(width: max(1040, min(1280, visibleSize.width - 40)), height: max(600, min(800, visibleSize.height - 40)))
  window = NSWindow(contentRect: NSRect(origin: .zero, size: initialSize), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
  window.isReleasedWhenClosed = false
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
  var options: [NSApplication.AboutPanelOptionKey: Any] = [
   .applicationName: "Form",
   .applicationVersion: version,
   .credits: NSAttributedString(string: "\(text("aboutDescription"))\nsupport@fdmwerk.de\nThree.js · Lucide · Open CASCADE / occt-import-js\n\(text("sourceLabel")): github.com/FDMwerk/Form")
  ]
  if let icon = Self.bundledApplicationIcon() { options[.applicationIcon] = icon }
  NSApplication.shared.orderFrontStandardAboutPanel(options: options)
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

 private func externalApps(for file: URL) -> [FormExternalApplication] {
  let workspace = NSWorkspace.shared
  let registered = workspace.urlsForApplications(toOpen: file)
  let known = FormExternalAppPolicy.knownIDs.compactMap { workspace.urlForApplication(withBundleIdentifier: $0) }
  let candidates = (registered + known).compactMap { url -> FormExternalApplication? in
   guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
   let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
   return FormExternalApplication(url: url, bundleID: id, name: name, registeredForFile: registered.contains(url))
  }
  return FormExternalAppPolicy.filtered(candidates, fileExtension: file.pathExtension, ownBundleID: Bundle.main.bundleIdentifier)
 }

 private func cancelSliceEstimate() {
  sliceRequestID = nil
  #if !FORM_APP_STORE
  sliceControl?.cancel()
  sliceControl = nil
  #endif
 }

 private func beginSliceEstimate(_ message: [String: Any]) {
  #if FORM_APP_STORE
  sendSliceEstimate(FormSliceRequestPolicy.error(message, code: "unsupported"))
  #else
  cancelSliceEstimate()
  guard let request = FormSliceRequestPolicy.parse(message) else {
   sendSliceEstimate(FormSliceRequestPolicy.error(message, code: "unsupported")); return
  }
  let requestID = request.requestID, material = request.material, scale = request.scale
  sliceRequestID = requestID
  web.callAsyncJavaScript("return window.selectedSourceID()", arguments: [:], in: nil, in: .page) { result in
   guard self.sliceRequestID == requestID else { return }
   guard case .success(let value) = result,
     let source = FormSliceRequestPolicy.source(request, selected: value, registry: self.sourceRegistry) else {
    self.sendSliceEstimate(FormSliceRequestPolicy.error(message, code: "unavailable")); return
   }
   let sourceID = request.sourceID
   let common: [String: Any] = ["requestID": requestID, "sourceID": sourceID,
    "printer": "Bambu Lab A1 mini", "nozzle": 0.4, "layerHeight": 0.2, "infill": 15, "material": material]
   guard source.pathExtension.lowercased() == "stl" else {
    self.sendSliceEstimate(common.merging(["state": "error", "errorCode": "unsupported"]) { _, latest in latest }); return
   }
   guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.bambulab.bambu-studio") else {
    self.sendSliceEstimate(common.merging(["state": "error", "errorCode": "unavailable"]) { _, latest in latest }); return
   }
   let control = FormBoundedProcess()
   self.sliceControl = control
   self.sendSliceEstimate(common.merging(["state": "working"]) { _, latest in latest })
   let scoped = source.startAccessingSecurityScopedResource()
   self.sliceWorker.async {
    let result = Result { try FormBambuSlicePolicy.estimate(application: app, source: source, material: material, scale: scale, control: control) }
    if scoped { source.stopAccessingSecurityScopedResource() }
    DispatchQueue.main.async {
     guard self.sliceRequestID == requestID else { return }
     self.sliceControl = nil
     var response = common
     switch result {
     case .success(let estimate): response["state"] = "complete"; response["seconds"] = estimate.seconds; response["grams"] = estimate.grams
     case .failure(let error):
      let failure = error as? FormBambuSlicePolicy.Failure
      response["state"] = failure == .cancelled ? "cancelled" : "error"
      switch failure {
      case .unsupported: response["errorCode"] = "unsupported"
      case .unavailable: response["errorCode"] = "unavailable"
      case .preset: response["errorCode"] = "preset"
      case .timeout: response["errorCode"] = "timeout"
      case .cancelled: response["errorCode"] = "cancelled"
      default: response["errorCode"] = "failed"
      }
     }
     self.sendSliceEstimate(response)
    }
   }
  }
  #endif
 }

 private func sendSliceEstimate(_ value: [String: Any]) {
  web.callAsyncJavaScript("window.applySliceEstimate(value)", arguments: ["value": value], in: nil, in: .page, completionHandler: nil)
 }

 private func installedPrintSoftware() -> [[String: String]] {
  let apps = FormExternalAppPolicy.slicerIDs.compactMap { id -> FormExternalApplication? in
   guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id), let bundle = Bundle(url: url),
     let actualID = bundle.bundleIdentifier else { return nil }
   let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
   return FormExternalApplication(url: url, bundleID: actualID, name: name, registeredForFile: true)
  }
  return FormExternalAppPolicy.filtered(apps, fileExtension: "stl", ownBundleID: Bundle.main.bundleIdentifier)
   .map { ["id": $0.bundleID, "name": $0.name] }
 }

 private func presentExternalError(_ key: String) {
  guard window.attachedSheet == nil else { return }
  let alert = NSAlert()
  alert.messageText = text("openWith")
  alert.informativeText = text(key)
  alert.addButton(withTitle: text("ok"))
  alert.beginSheetModal(for: window, completionHandler: nil)
 }

 private func openWithMenu(slicersOnly: Bool = false) {
  guard ready, window.attachedSheet == nil else { return }
  web.callAsyncJavaScript("return window.selectedSourceID()", arguments: [:], in: nil, in: .page) { result in
   guard case .success(let value) = result, let file = self.sourceRegistry.sourceURL(for: value) else {
    self.presentExternalError("openWithNoSource"); return
   }
   let scoped = file.startAccessingSecurityScopedResource()
   defer { if scoped { file.stopAccessingSecurityScopedResource() } }
   guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
    self.presentExternalError("openWithUnavailable"); return
   }
   let apps = self.externalApps(for: file).filter { !slicersOnly || FormExternalAppPolicy.isSlicer($0.bundleID) }
   let menu = NSMenu(title: self.text("openWith"))
   let printService = menu.addItem(withTitle: self.text("printAtFDMwerk"), action: #selector(self.openFDMwerkPrintService), keyEquivalent: "")
   printService.target = self
   if let icon = Self.bundledApplicationIcon()?.copy() as? NSImage {
    icon.size = NSSize(width: 22, height: 22)
    printService.image = icon
   }
   if !apps.isEmpty { menu.addItem(.separator()) }
   for app in apps {
    let item = menu.addItem(withTitle: app.name, action: #selector(self.openExternalApplication(_:)), keyEquivalent: "")
    item.target = self
    item.representedObject = FormExternalMenuTarget(app: app, file: file)
    let icon = (NSWorkspace.shared.icon(forFile: app.url.path).copy() as? NSImage) ?? NSWorkspace.shared.icon(forFile: app.url.path)
    icon.isTemplate = false
    icon.size = NSSize(width: 22, height: 22)
    item.image = icon
   }
   let point = NSPoint(x: max(0, self.web.bounds.width - 190), y: self.web.isFlipped ? 60 : self.web.bounds.height - 60)
   menu.popUp(positioning: nil, at: point, in: self.web)
  }
 }

 private func showFeedbackMenu() {
  let menu = NSMenu(title: text("featureRequest"))
  let email = menu.addItem(withTitle: text("feedbackEmail"), action: #selector(openFeedbackEmail), keyEquivalent: "")
  email.target = self
  email.image = NSImage(systemSymbolName: "envelope", accessibilityDescription: nil)
  let github = menu.addItem(withTitle: text("feedbackGitHub"), action: #selector(openFeedbackGitHub), keyEquivalent: "")
  github.target = self
  github.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: nil)
  menu.popUp(positioning: nil, at: NSPoint(x: 24, y: web.isFlipped ? web.bounds.height - 180 : 180), in: web)
 }
 @objc private func openFeedbackEmail() { NSWorkspace.shared.open(FormFeedbackPolicy.emailURL) }
 @objc private func openFeedbackGitHub() { NSWorkspace.shared.open(FormFeedbackPolicy.githubURL) }

 @objc private func openFDMwerkPrintService() {
  // This opens the public service page only; model files are never uploaded.
  if let url = URL(string: "https://fdmwerk.de") { NSWorkspace.shared.open(url) }
 }

 @objc private func openExternalApplication(_ sender: NSMenuItem) {
  guard let target = sender.representedObject as? FormExternalMenuTarget else { return }
  let file = target.file
  let scoped = file.startAccessingSecurityScopedResource()
  guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
   if scoped { file.stopAccessingSecurityScopedResource() }
   presentExternalError("openWithUnavailable"); return
  }
  let configuration = NSWorkspace.OpenConfiguration()
  configuration.activates = true
  var documents = [file]
  if target.app.bundleID.lowercased() == FormExternalAppPolicy.blenderID {
   #if FORM_APP_STORE
   if scoped { file.stopAccessingSecurityScopedResource() }
   presentExternalError("openWithError")
   return
   #else
   do {
    let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Form/ExternalImport", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let script = directory.appendingPathComponent("blender-import.py")
    try FormExternalAppPolicy.blenderScript.write(to: script, atomically: true, encoding: .utf8)
    guard let arguments = FormExternalAppPolicy.blenderArguments(script: script, file: file) else { throw NSError(domain: "Form.External", code: 1) }
    configuration.arguments = arguments
    configuration.createsNewApplicationInstance = true
    documents = []
   } catch {
    if scoped { file.stopAccessingSecurityScopedResource() }
    presentExternalError("openWithBlenderError"); return
   }
   #endif
  }
  NSWorkspace.shared.open(documents, withApplicationAt: target.app.url, configuration: configuration) { _, error in
   if scoped { file.stopAccessingSecurityScopedResource() }
   if error != nil { DispatchQueue.main.async { self.presentExternalError("openWithError") } }
  }
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
  // Let the native chooser offer every file, independent of third-party UTI
  // registrations. The importer validates format, regular-file status and size
  // after the user confirms and security-scoped access becomes available.
  panel.allowedContentTypes = [.item]
  panel.allowsOtherFileTypes = true
  panel.canChooseFiles = true
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
  if let data = message.body as? [String: Any], data["type"] as? String == "sliceEstimate" {
   beginSliceEstimate(data)
   return
  }
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
   let completeStartup = {
    self.web.callAsyncJavaScript("window.applyNativeCapabilities(capabilities)", arguments: ["capabilities": FormBuildCapabilities.dictionary], in: nil, in: .page) { _ in
     self.web.callAsyncJavaScript("window.applyPrintSoftware(software)", arguments: ["software": self.installedPrintSoftware()], in: nil, in: .page) { _ in self.imports.setReady() }
    }
   }
   web.callAsyncJavaScript("window.applySystemLanguages(languages)", arguments: ["languages": Locale.preferredLanguages], in: nil, in: .page) { _ in
    if let saved = UserDefaults.standard.dictionary(forKey: self.preferencesKey), let clean = FormPreferencePolicy.sanitize(saved) {
     self.web.callAsyncJavaScript("window.applyViewportSettings(value)", arguments: ["value": clean], in: nil, in: .page) { _ in completeStartup() }
    } else { completeStartup() }
   }
  case "open": openPanel()
  case "openWith": openWithMenu()
  case "openInSlicer": openWithMenu(slicersOnly: true)
  case "cancelSliceEstimate": cancelSliceEstimate()
  case "feedback": showFeedbackMenu()
  case "legal": showLegal()
  case "donate":
   #if !FORM_APP_STORE
   NSWorkspace.shared.open(FormSupportPolicy.donationURL)
   #endif
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

 func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
  if !flag {
   window?.makeKeyAndOrderFront(nil)
   sender.activate(ignoringOtherApps: true)
  }
  return true
 }

 func applicationWillTerminate(_ notification: Notification) { cancelSliceEstimate() }

 func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
