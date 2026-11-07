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
  try check(FormBuildCapabilities.externalSliceEstimate && FormBuildCapabilities.blenderImport, "Desktop integrations unexpectedly disabled")
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

  let origin = FormSourceRegistry()
  let firstID = UUID().uuidString, secondID = UUID().uuidString, rejectedID = UUID().uuidString
  let sameName = directory.appendingPathComponent("other/part.STL")
  origin.record(firstID, url: good, imported: true)
  origin.record(secondID, url: sameName, imported: true)
  origin.record(rejectedID, url: empty, imported: false)
  try check(origin.sourceURL(for: firstID) == good && origin.sourceURL(for: secondID) == sameName, "Duplicate filenames confused source identity")
  try check(origin.sourceURL(for: rejectedID) == nil && origin.sourceURL(for: NSNull()) == nil && origin.sourceURL(for: good.path) == nil, "Rejected import or path became a source identity")
  let blender = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/Blender.app"), bundleID: FormExternalAppPolicy.blenderID, name: "Blender", registeredForFile: false)
  let bambu = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/BambuStudio.app"), bundleID: "com.bambulab.bambu-studio", name: "Bambu Studio", registeredForFile: false)
  let fusion = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/Fusion.app"), bundleID: "com.autodesk.fusion360", name: "Fusion", registeredForFile: false)
  let cad = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/CAD Assistant.app"), bundleID: "org.opencascade.cadassistant", name: "CAD Assistant", registeredForFile: false)
  let viewer = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/Other.app"), bundleID: "example.viewer", name: "Other", registeredForFile: true)
  let selfApp = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/Form.app"), bundleID: "de.fdmwerk.form", name: "Form", registeredForFile: true)
  let archived = FormExternalApplication(url: URL(fileURLWithPath: "/tmp/Archives/test.xcarchive/Other.app"), bundleID: "example.archive", name: "Archive", registeredForFile: true)
  let built = FormExternalApplication(url: URL(fileURLWithPath: "/tmp/build/Test.app"), bundleID: "example.build", name: "Build", registeredForFile: true)
  let unregistered = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/Unknown.app"), bundleID: "example.unknown", name: "Unknown", registeredForFile: false)
  let filtered = FormExternalAppPolicy.filtered([blender, bambu, fusion, cad, viewer, selfApp, archived, built, unregistered, blender], fileExtension: "STL", ownBundleID: "de.fdmwerk.form")
  try check(Set(filtered.map { $0.bundleID }) == Set([blender.bundleID, bambu.bundleID, fusion.bundleID, cad.bundleID, viewer.bundleID]) && filtered.count == 5, "Discovery did not filter unsupported/self/build/archive/duplicate applications")
  try check(!FormExternalAppPolicy.compatible(blender, fileExtension: "step") && !FormExternalAppPolicy.compatible(blender, fileExtension: "3mf"), "Blender offered without a supported importer")
  try check(!FormExternalAppPolicy.compatible(bambu, fileExtension: "glb") && !FormExternalAppPolicy.compatible(fusion, fileExtension: "gltf"), "Known CAD app offered unsupported glTF")
  try check(FormExternalAppPolicy.filtered([blender, bambu, cad], fileExtension: "exe", ownBundleID: nil).isEmpty, "Unsupported input reached external apps")
  let scriptURL = directory.appendingPathComponent("Blender import.py")
  let trickyFile = directory.appendingPathComponent("a 'quoted'; $(touch bad) model.STL")
  try check(FormExternalAppPolicy.blenderArguments(script: scriptURL, file: trickyFile) == ["--python", scriptURL.path, "--", trickyFile.path], "Blender arguments changed a file path or interpolated code")
  try check(FormExternalAppPolicy.blenderArguments(script: scriptURL, file: empty) == nil, "STEP passed to Blender import script")
  try FormExternalAppPolicy.blenderScript.write(to: scriptURL, atomically: true, encoding: .utf8)
  let pythonTest = """
  import sys, types, runpy
  script = sys.argv[1]
  calls = []
  class Ops:
      def __init__(self, prefix=''): self.prefix = prefix
      def __getattr__(self, name): return Ops(self.prefix + '.' + name)
      def __call__(self, **kwargs): calls.append((self.prefix, kwargs))
  bpy = types.SimpleNamespace(ops=Ops(), app=types.SimpleNamespace(version=(4, 3, 0)), context=types.SimpleNamespace(screen=None))
  sys.modules['bpy'] = bpy
  for ext, operator in [('stl', '.wm.stl_import'), ('obj', '.wm.obj_import'), ('ply', '.wm.ply_import'), ('glb', '.import_scene.gltf'), ('gltf', '.import_scene.gltf')]:
      calls.clear()
      path = "/tmp/a 'quoted'; $(touch bad)." + ext
      sys.argv = ['blender', '--python', script, '--', path]
      runpy.run_path(script, run_name='__main__')
      assert (operator, {'filepath': path}) in calls, (ext, calls)
  bpy.app.version = (3, 6, 0)
  calls.clear()
  sys.argv = ['blender', '--python', script, '--', '/tmp/test.stl']
  runpy.run_path(script, run_name='__main__')
  assert ('.import_mesh.stl', {'filepath': '/tmp/test.stl'}) in calls
  print('PASS actual Blender script: five import operators, literal paths, legacy STL fallback')
  """
  let python = Process()
  python.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  python.arguments = ["python3", "-c", pythonTest, scriptURL.path]
  try python.run(); python.waitUntilExit()
  try check(python.terminationStatus == 0, "Actual Blender script execution failed")
  print("PASS external-app policies: source identity, duplicate filenames, success-only mapping, installed-app filtering, format restrictions, safe launch arguments")

  let timeoutControl = FormBoundedProcess()
  let timedOut = try timeoutControl.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], timeout: 0.1)
  try check(timedOut == .timedOut, "External process deadline was not enforced")
  let cancelControl = FormBoundedProcess()
  DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { cancelControl.cancel() }
  let cancelled = try cancelControl.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], timeout: 2)
  try check(cancelled == .cancelled, "External process cancellation failed")
  let beforeStart = FormBoundedProcess(); beforeStart.cancel()
  let cancelledBeforeStart = try beforeStart.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], timeout: 2)
  try check(cancelledBeforeStart == .cancelled, "Cancelled job launched a new process")
  let requestMessage: [String: Any] = ["requestID": "slice-12345", "sourceID": firstID, "material": "PLA", "scale": 1]
  let sliceRequest = FormSliceRequestPolicy.parse(requestMessage)!
  try check(FormSliceRequestPolicy.source(sliceRequest, selected: firstID, registry: origin) == good, "Matching selected native source was rejected")
  try check(FormSliceRequestPolicy.source(sliceRequest, selected: secondID, registry: origin) == nil && FormSliceRequestPolicy.source(sliceRequest, selected: NSNull(), registry: origin) == nil, "Selection race or absent source reached slicer")
  for changes: [String: Any] in [["material": "unknown"], ["scale": Double.nan], ["scale": -1], ["sourceID": "missing"], ["requestID": String(repeating: "a", count: 129)]] {
   let invalid = requestMessage.merging(changes) { _, value in value }
   try check(FormSliceRequestPolicy.parse(invalid) == nil, "Invalid slice request accepted")
   let response = FormSliceRequestPolicy.error(invalid, code: "unsupported")
   try check(response["requestID"] as? String == invalid["requestID"] as? String && response["sourceID"] as? String == invalid["sourceID"] as? String && response["state"] as? String == "error", "Rejected request lost callback identity and would leave the UI spinning")
  }
  let unavailableResponse = FormSliceRequestPolicy.error(requestMessage, code: "unavailable")
  try check(unavailableResponse["requestID"] as? String == "slice-12345" && unavailableResponse["sourceID"] as? String == firstID, "Unavailable-source response lost request/source binding")
  print("PASS slice request bridge: opaque bounded request IDs, source binding, selection race, explicit identity-preserving rejection")

  let presetIndex: [String: [String: Any]] = ["base": ["name": "base", "wall_loops": "2", "layer_height": "0.3"], "template": ["machine_start_gcode": "SAFE"], "leaf": ["name": "leaf", "inherits": "base", "include": ["template"], "layer_height": "0.2"]]
  let merged = try FormBambuSlicePolicy.mergedPreset("leaf", index: presetIndex)
  try check(merged["wall_loops"] as? String == "2" && merged["layer_height"] as? String == "0.2" && merged["machine_start_gcode"] as? String == "SAFE" && merged["inherits"] == nil && merged["include"] == nil, "Bundled slicer preset inheritance/include merge failed")
  do { _ = try FormBambuSlicePolicy.mergedPreset("cycle", index: ["cycle": ["inherits": "cycle"]]); throw CheckFailure.failed("Cyclic preset accepted") } catch FormBambuSlicePolicy.Failure.preset { }
  try check(FormBambuSlicePolicy.materialName("PLA") != nil && FormBambuSlicePolicy.materialName("PETG") != nil && FormBambuSlicePolicy.materialName("custom/path") == nil, "Slicer material allowlist failed")
  let sliceJSON = Data(#"{"return_code":0,"sliced_plates":[{"total_predication":123.5,"filaments":[{"total_used_g":2.4}]}]}"#.utf8)
  let sliceResult = try FormBambuSlicePolicy.result(sliceJSON)
  try check(sliceResult.seconds == 123.5 && sliceResult.grams == 2.4, "Slicer result time/weight units changed")
  for invalid in [#"{}"#, #"{"return_code":0,"sliced_plates":[]}"#, #"{"return_code":0,"sliced_plates":[{"total_predication":-1,"filaments":[{"total_used_g":2}]}]}"#] {
   do { _ = try FormBambuSlicePolicy.result(Data(invalid.utf8)); throw CheckFailure.failed("Invalid slicer result accepted") } catch FormBambuSlicePolicy.Failure.failed { }
  }
  try check(FormExternalAppPolicy.isSlicer("com.bambulab.bambu-studio") && FormExternalAppPolicy.isSlicer("com.orcaslicer.OrcaSlicer") && !FormExternalAppPolicy.isSlicer(FormExternalAppPolicy.blenderID), "Installed slicer classification failed")
  print("PASS slicer adapter policies: inheritance/include overrides, cycle rejection, material allowlist, result bounds/units, process timeout/cancellation/pre-cancel, slicer identities")

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
