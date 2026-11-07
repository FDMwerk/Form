import Foundation
import CoreGraphics
import ImageIO

private enum CheckFailure: Error, CustomStringConvertible {
 case failed(String)
 var description: String { switch self { case .failed(let message): return message } }
}
private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
 if !condition() { throw CheckFailure.failed(message) }
}
private func expectImportFailure(_ code: Int, _ work: () throws -> Void) throws {
 do { try work(); throw CheckFailure.failed("Expected import failure code \(code)") }
 catch let error as NSError where error.domain == "Form.Import" { try check(error.code == code, "Wrong import policy error \(error)") }
}
private final class QueueHarness {
 var reads: [(URL, (Result<Data, Error>) -> Void)] = []
 var parses: [(URL, Data, (Result<Bool, Error>) -> Void)] = []
 var recents: [URL] = []
 var errors: [(Error, () -> Void)] = []
 lazy var queue = FormImportQueue(
  read: { self.reads.append(($0, $1)) },
  importData: { self.parses.append(($0, $1, $2)) },
  didImport: { self.recents.append($0) },
  presentError: { self.errors.append(($0, $1)) }
 )
}

@main
struct NativePolicyTests {
 static func main() throws {
  let files = FileManager.default
  let directory = files.temporaryDirectory.appendingPathComponent("form-native-tests-" + UUID().uuidString, isDirectory: true)
  try files.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? files.removeItem(at: directory) }
  let good = directory.appendingPathComponent("part.STL")
  let bytes = Data("solid test\nendsolid test".utf8)
  try bytes.write(to: good)
  let loaded = try FormImportPolicy.read(good, maximumBytes: bytes.count)
  try check(loaded == bytes, "Supported uppercase extension or exact-byte boundary rejected")
  // The native policy is deliberately not the model parser: arbitrary nonempty STL bytes proceed to the viewer's parser.
  try expectImportFailure(3) { _ = try FormImportPolicy.read(good, maximumBytes: bytes.count - 1) }
  let unsupported = directory.appendingPathComponent("part.exe")
  try bytes.write(to: unsupported)
  try expectImportFailure(1) { _ = try FormImportPolicy.read(unsupported) }
  try expectImportFailure(1) { _ = try FormImportPolicy.read(URL(string: "https://example.com/model.stl")!) }
  let folder = directory.appendingPathComponent("folder.stl", isDirectory: true)
  try files.createDirectory(at: folder, withIntermediateDirectories: true)
  try expectImportFailure(2) { _ = try FormImportPolicy.read(folder) }
  let empty = directory.appendingPathComponent("empty.step")
  try Data().write(to: empty)
  try expectImportFailure(4) { _ = try FormImportPolicy.read(empty) }
  let missing = directory.appendingPathComponent("missing.step")
  do { _ = try FormImportPolicy.read(missing); throw CheckFailure.failed("Missing file accepted") } catch is CocoaError { }
  print("PASS native file reads: supported uppercase type, exact size, oversized, unsupported, non-file URL, directory, empty, missing")

  let pixels: [UInt8] = [255, 0, 0, 255]
  let provider = CGDataProvider(data: Data(pixels) as CFData)!
  let image = CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
   decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
  let png = NSMutableData()
  let destination = CGImageDestinationCreateWithData(png, "public.png" as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, image, nil)
  try check(CGImageDestinationFinalize(destination), "Unable to create PNG fixture")
  let pngData = png as Data
  let decodedPNG = try FormScreenshotPolicy.decode(pngData.base64EncodedString())
  try check(decodedPNG == pngData, "Valid PNG rejected")
  for invalid: Any in [42, "", "not-base64", Data("hello".utf8).base64EncodedString(), pngData.prefix(12).base64EncodedString()] {
   do { _ = try FormScreenshotPolicy.decode(invalid); throw CheckFailure.failed("Malformed PNG accepted") }
   catch let error as NSError where error.domain == "Form.Screenshot" { }
  }
  let oversizedEncoded = String(repeating: "A", count: (FormScreenshotPolicy.maximumBytes / 3 + 1) * 4 + 1)
  do { _ = try FormScreenshotPolicy.decode(oversizedEncoded); throw CheckFailure.failed("Oversized PNG payload accepted") }
  catch let error as NSError where error.domain == "Form.Screenshot" { }
  print("PASS PNG screenshot validation: real encoded PNG, invalid type/base64/signature/truncated image, oversized payload")

  try check(FormPreferencePolicy.sanitize([:]) == nil, "Missing preset accepted")
  try check(FormPreferencePolicy.sanitize(["preset": "unknown"]) == nil, "Unknown preset accepted")
  let clean = FormPreferencePolicy.sanitize([
   "preset": "fusion", "orbitSpeed": Double.nan, "zoomSpeed": 99,
   "reverseZoom": "true", "trackpad": true, "defaultColor": "#a0B4c9",
   "componentColors": true, "showTextures": false, "externalURL": "https://example.com"
  ])!
  try check((clean["orbitSpeed"] as? NSNumber)?.doubleValue == 1, "Nonfinite preference survived")
  try check((clean["zoomSpeed"] as? NSNumber)?.doubleValue == 3, "Speed not bounded")
  try check(clean["reverseZoom"] as? Bool == false, "String became bool")
  try check(clean["trackpad"] as? Bool == true && clean["componentColors"] as? Bool == true && clean["showTextures"] as? Bool == false, "Display/nav flags lost")
  try check(clean["defaultColor"] as? String == "#a0B4c9", "Valid color lost")
  try check(clean["externalURL"] == nil, "Unknown preference retained")
  let invalidColor = FormPreferencePolicy.sanitize(["preset": "bambu", "defaultColor": "red; alert(1)", "orbitSpeed": -20])!
  try check(invalidColor["defaultColor"] == nil && (invalidColor["orbitSpeed"] as? NSNumber)?.doubleValue == 0.2, "Invalid color or low speed survived")
  let roundTrip = try PropertyListSerialization.propertyList(from: PropertyListSerialization.data(fromPropertyList: clean, format: .binary, options: 0), options: [], format: nil) as! [String: Any]
  try check(FormPreferencePolicy.sanitize(roundTrip)?["componentColors"] as? Bool == true, "Preference property-list round trip failed")
  let suiteName = "de.fdmwerk.form.native-tests." + UUID().uuidString
  let defaults = UserDefaults(suiteName: suiteName)!
  defaults.set(clean, forKey: "FormViewportPreferences")
  let restored = FormPreferencePolicy.sanitize(defaults.dictionary(forKey: "FormViewportPreferences") ?? [:])
  defaults.removePersistentDomain(forName: suiteName)
  try check(restored?["preset"] as? String == "fusion" && restored?["defaultColor"] as? String == "#a0B4c9" && restored?["showTextures"] as? Bool == false, "Actual UserDefaults round trip lost persisted display/navigation values")
  print("PASS preferences: allowlist, finite/clamped speeds, strict color, flags, unknown fields, property-list and isolated UserDefaults round trips")

  try check(clean["language"] as? String == "system", "Existing preferences did not default to system language")
  try check(FormLanguagePolicy.preference("PT_br") == "pt-BR", "Locale preference canonicalization failed")
  for invalid: Any in ["xx", "", String(repeating: "a", count: 10000), 42, ["de"]] {
   try check(FormLanguagePolicy.preference(invalid) == "system", "Invalid language preference survived")
  }
  try check(FormLanguagePolicy.resolve("system", preferredLanguages: ["de-CH", "fr"]) == "de", "Regional system language did not use base")
  try check(FormLanguagePolicy.resolve("system", preferredLanguages: ["xx-XX", "fr-CA"]) == "fr", "Secondary system language was ignored")
  try check(FormLanguagePolicy.resolve("ja", preferredLanguages: ["de"]) == "ja", "Explicit language did not override system")
  try check(FormLanguagePolicy.resolve("system", preferredLanguages: ["pt_BR"]) == "pt-BR", "Exact regional language lost")
  try check(FormLanguagePolicy.resolve("system", preferredLanguages: ["zh-TW"]) == "zh-Hant", "Traditional Chinese regional fallback failed")
  try check(FormLanguagePolicy.resolve("system", preferredLanguages: ["zh-CN"]) == "zh-Hans", "Simplified Chinese regional fallback failed")
  try check(FormLanguagePolicy.resolve("system", preferredLanguages: ["no-NO"]) == "nb", "Norwegian alias failed")
  try check(FormLanguagePolicy.resolve("system", preferredLanguages: ["xx", String(repeating: "a", count: 10000)]) == "en", "Unknown/extreme locale did not fall back to English")
  try check(FormLanguagePolicy.resolve("system", preferredLanguages: ["de"], available: ["en"]) == "en", "Missing native catalog did not fall back")
  try check(FormLanguagePolicy.resolve("system", preferredLanguages: []) == "en", "Empty system languages did not fall back")
  print("PASS native languages: default system, explicit/region/base/script/secondary fallback, canonicalization, invalid/extreme values, missing catalog")

  let root = directory.appendingPathComponent("Web", isDirectory: true)
  try files.createDirectory(at: root, withIntermediateDirectories: true)
  let index = root.appendingPathComponent("index.html")
  try Data().write(to: index)
  try check(FormBridgePolicy.acceptsMessage(source: index, root: root, isMainFrame: true, isViewerWebView: true), "Trusted bridge rejected")
  try check(!FormBridgePolicy.acceptsMessage(source: index, root: root, isMainFrame: false, isViewerWebView: true), "Subframe bridge accepted")
  try check(!FormBridgePolicy.acceptsMessage(source: index, root: root, isMainFrame: true, isViewerWebView: false), "Other WKWebView bridge accepted")
  try check(!FormBridgePolicy.acceptsMessage(source: root.appendingPathComponent("legal.html"), root: root, isMainFrame: true, isViewerWebView: true), "Legal document got native bridge")
  try check(!FormBridgePolicy.acceptsMessage(source: root.appendingPathComponent("nested/index.html"), root: root, isMainFrame: true, isViewerWebView: true), "Nested index impersonated main viewer")
  try check(!FormBridgePolicy.isBundledWebURL(directory.appendingPathComponent("Web-evil/index.html"), root: root), "Sibling prefix escaped root")
  let symlink = root.appendingPathComponent("escape.html")
  try files.createSymbolicLink(at: symlink, withDestinationURL: good)
  try check(!FormBridgePolicy.isBundledWebURL(symlink, root: root), "Symlink escaped bundle root")
  try check(!FormBridgePolicy.isBundledWebURL(URL(string: "https://example.com/index.html")!, root: root), "Remote URL became bundled")
  print("PASS bridge/navigation boundary: main document, frame/view identity, sibling prefix, nested index, symlink, remote URL")

  let a = directory.appendingPathComponent("a.stl"), b = directory.appendingPathComponent("b.step"), c = directory.appendingPathComponent("c.obj")
  let h = QueueHarness()
  h.queue.enqueue(a); h.queue.enqueue(b)
  try check(h.reads.isEmpty && h.queue.pendingCount == 2, "Startup import began before viewer preferences were ready")
  h.queue.setReady(); h.queue.setReady()
  try check(h.reads.map { $0.0 } == [a], "Startup ready lost ordering or read twice")
  h.queue.enqueue(c)
  h.reads[0].1(.success(bytes))
  try check(h.parses.map { $0.0 } == [a] && h.reads.count == 1, "Queue did not wait for viewer import")
  // Misbehaving/stale callbacks must not duplicate imports or advance a newer operation.
  h.reads[0].1(.success(bytes))
  try check(h.parses.count == 1, "Duplicate read callback parsed twice")
  h.parses[0].2(.success(true))
  try check(h.recents == [a] && h.reads.map { $0.0 } == [a, b], "Successful import did not update recents then advance")
  h.parses[0].2(.success(true))
  try check(h.recents == [a] && h.reads.count == 2, "Stale parser callback duplicated recents")
  h.reads[1].1(.success(bytes)); h.parses[1].2(.success(false))
  try check(h.recents == [a] && h.reads.map { $0.0 } == [a, b, c], "Rejected parser output entered recents or stalled batch")
  h.reads[2].1(.failure(NSError(domain: "test.read", code: 1)))
  let d = directory.appendingPathComponent("d.glb")
  h.queue.enqueue(d)
  try check(h.errors.count == 1 && h.reads.count == 3 && h.queue.isProcessing, "Read failure did not pause queue for error dismissal")
  h.errors[0].1()
  try check(h.reads.map { $0.0 } == [a, b, c, d], "Error dismissal did not resume next file")
  h.errors[0].1()
  try check(h.reads.count == 4, "Duplicate error dismissal advanced queue twice")
  h.reads[3].1(.success(bytes)); h.parses[2].2(.failure(NSError(domain: "test.bridge", code: 2)))
  try check(h.errors.count == 2 && h.recents == [a], "JavaScript bridge failure was not surfaced or entered recents")
  h.errors[1].1()
  try check(!h.queue.isProcessing && h.queue.pendingCount == 0, "Queue did not finish cleanly after bridge error")
  print("PASS real import coordinator: startup gate, ordered batch, read/import serialization, success-only recents, rejected parse, read/bridge errors, dismissal pause, duplicate callbacks")
 }
}
