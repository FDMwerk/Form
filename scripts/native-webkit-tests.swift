import AppKit
import WebKit

/// Exercises actual production async-function bodies in WebKit, not JavaScript eval semantics.
@main
final class NativeWebKitTests: NSObject, NSApplicationDelegate, WKNavigationDelegate {
 private var view: WKWebView!
 private var importBody = ""
 private var selectionBodies: [String] = []
 private let sourceID = UUID().uuidString
 private let registry = FormSourceRegistry()
 private var source: URL!
 static func main() {
  let application = NSApplication.shared
  let delegate = NativeWebKitTests()
  application.delegate = delegate
  application.setActivationPolicy(.prohibited)
  DispatchQueue.main.asyncAfter(deadline: .now() + 20) { delegate.fail("WebKit bridge test timed out") }
  withExtendedLifetime(delegate) { application.run() }
 }
 private func fail(_ message: String) -> Never {
  fputs("FAIL actual WebKit bridge: \(message)\n", stderr)
  exit(1)
 }
 func applicationDidFinishLaunching(_ notification: Notification) {
  do {
   let appSource = try String(contentsOf: Bundle.main.url(forResource: "ProductionApp", withExtension: "swift")!, encoding: .utf8)
   let regex = try NSRegularExpression(pattern: #"callAsyncJavaScript\("([^"]+)""#)
   let bodies = regex.matches(in: appSource, range: NSRange(appSource.startIndex..., in: appSource)).compactMap { match -> String? in
    guard let range = Range(match.range(at: 1), in: appSource) else { return nil }
    return String(appSource[range])
   }
   guard let body = bodies.first(where: { $0.contains("window.openModel(") }) else { fail("Production import body missing") }
   importBody = body
   selectionBodies = bodies.filter { $0.contains("window.selectedSourceID()") }
   guard selectionBodies.count == 2 else { fail("Expected both production selection call sites") }
   source = Bundle.main.url(forResource: "bridge", withExtension: "html")!
   let configuration = WKWebViewConfiguration()
   configuration.websiteDataStore = .nonPersistent()
   view = WKWebView(frame: NSRect(x: 0, y: 0, width: 320, height: 240), configuration: configuration)
   view.navigationDelegate = self
   view.loadFileURL(source, allowingReadAccessTo: source.deletingLastPathComponent())
  } catch { fail(String(describing: error)) }
 }
 func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
  view.callAsyncJavaScript(importBody, arguments: ["name": "accepted.stl", "bytes": "c3Rs", "sourceID": sourceID], in: nil, in: .page) { result in
   guard case .success(let value) = result, (value as? Bool) == true else { self.fail("Successful import did not return Bool true: \(result)") }
   self.registry.record(self.sourceID, url: self.source, imported: true)
   self.checkSelection(0)
  }
 }
 private func checkSelection(_ index: Int) {
  guard index < selectionBodies.count else { checkRejectedImport(); return }
  view.callAsyncJavaScript(selectionBodies[index], arguments: [:], in: nil, in: .page) { result in
   guard case .success(let value) = result, value as? String == self.sourceID,
     self.registry.sourceURL(for: value) == self.source else { self.fail("Selection call \(index) lost source identity: \(result)") }
   self.checkSelection(index + 1)
  }
 }
 private func checkRejectedImport() {
  let rejectedID = UUID().uuidString
  view.callAsyncJavaScript(importBody, arguments: ["name": "rejected.stl", "bytes": "c3Rs", "sourceID": rejectedID], in: nil, in: .page) { result in
   guard case .success(let value) = result, (value as? Bool) == false else { self.fail("Rejected import did not return Bool false: \(result)") }
   self.registry.record(rejectedID, url: self.source, imported: (value as? Bool) == true)
   guard self.registry.sourceURL(for: rejectedID) == nil else { self.fail("Rejected import was recorded") }
   print("PASS actual sandboxed WebKit: production async import Bool true/false, both selection String returns, source registry success/rejection")
   fflush(stdout)
   NSApplication.shared.terminate(nil)
  }
 }
}
