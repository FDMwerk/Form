import Foundation
import ImageIO
import Darwin

/// The same read policy used by the native importer and its regression tests.
enum FormImportPolicy {
 static let maximumFileBytes = 250_000_000
 static let supportedExtensions = ["stl", "step", "stp", "iges", "igs", "brep", "brp", "obj", "ply", "3mf", "gltf", "glb"]

 static func read(_ url: URL, maximumBytes: Int = maximumFileBytes) throws -> Data {
  func failure(_ code: Int, _ message: String) -> NSError {
   NSError(domain: "Form.Import", code: code, userInfo: [NSLocalizedDescriptionKey: message])
  }
  guard url.isFileURL, supportedExtensions.contains(url.pathExtension.lowercased()) else {
   throw failure(1, "This file format is not supported.")
  }
  let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
  guard values.isRegularFile == true else { throw failure(2, "Please open a model file, not a folder.") }
  guard maximumBytes > 0, maximumBytes < Int.max,
        (values.fileSize ?? 0) <= maximumBytes else { throw failure(3, "This preview opens files up to 250 MB.") }
  let handle = try FileHandle(forReadingFrom: url)
  defer { try? handle.close() }
  var data = Data()
  // Read in bounded chunks, including the case where a file grows after its initial stat.
  while data.count <= maximumBytes {
   let count = min(1_048_576, maximumBytes + 1 - data.count)
   let chunk = try handle.read(upToCount: count) ?? Data()
   if chunk.isEmpty { break }
   data.append(chunk)
  }
  guard !data.isEmpty else { throw failure(4, "The selected file is empty.") }
  guard data.count <= maximumBytes else { throw failure(3, "This preview opens files up to 250 MB.") }
  return data
 }
}

enum FormScreenshotPolicy {
 static let maximumBytes = 50_000_000
 static func decode(_ value: Any?) throws -> Data {
  func invalid() -> NSError { NSError(domain: "Form.Screenshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid PNG screenshot."]) }
  guard let encoded = value as? String, encoded.utf8.count <= (maximumBytes / 3 + 1) * 4,
        let data = Data(base64Encoded: encoded), data.count <= maximumBytes,
        data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
        let source = CGImageSourceCreateWithData(data as CFData, nil),
        CGImageSourceGetType(source) as String? == "public.png",
        CGImageSourceGetStatus(source) == .statusComplete,
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? Int,
        let height = properties[kCGImagePropertyPixelHeight] as? Int,
        width > 0, height > 0, width <= 10000, height <= 10000, width * height <= 32_000_000,
        CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw invalid() }
  return data
 }
}

enum FormLanguagePolicy {
 static let supportedCodes = ["en", "de", "fr", "es", "it", "pt", "pt-BR", "nl", "da", "sv", "nb", "fi", "is", "pl", "cs", "sk", "hu", "ro", "bg", "hr", "sl", "sr", "el", "tr", "ru", "uk", "ca", "eu", "gl", "ar", "he", "fa", "hi", "th", "vi", "id", "ms", "ja", "ko", "zh-Hans", "zh-Hant"]
 static func preference(_ value: Any?) -> String {
  guard let raw = value as? String, raw.count <= 35 else { return "system" }
  if raw == "system" { return raw }
  return supportedCodes.first { $0.lowercased() == raw.replacingOccurrences(of: "_", with: "-").lowercased() } ?? "system"
 }
 static func resolve(_ preference: String, preferredLanguages: [String], available: [String] = supportedCodes) -> String {
  let requested = preference == "system" ? preferredLanguages : [preference]
  for raw in requested where raw.count <= 100 {
   let code = raw.replacingOccurrences(of: "_", with: "-").lowercased()
   if let exact = available.first(where: { $0.lowercased() == code }) { return exact }
   let base = code.split(separator: "-").first.map(String.init) ?? ""
   if base == "zh" {
    let variant = code.contains("hant") || code.contains("-tw") || code.contains("-hk") || code.contains("-mo") ? "zh-Hant" : "zh-Hans"
    if available.contains(variant) { return variant }
   }
   let normalized = base == "no" ? "nb" : base
   if let match = available.first(where: { $0.lowercased() == normalized }) { return match }
  }
  return "en"
 }
}

enum FormPreferencePolicy {
 static func sanitize(_ value: [String: Any]) -> [String: Any]? {
  let presets = ["bambu", "fusion", "blender", "solidworks", "onshape"]
  guard let preset = value["preset"] as? String, presets.contains(preset) else { return nil }
  var clean: [String: Any] = ["preset": preset, "language": FormLanguagePolicy.preference(value["language"])]
  for key in ["orbitSpeed", "zoomSpeed"] {
   let candidate = (value[key] as? NSNumber)?.doubleValue ?? 1
   clean[key] = candidate.isFinite ? min(3, max(0.2, candidate)) : 1
  }
  for key in ["reverseZoom", "trackpad", "componentColors", "showTextures", "showGrid"] {
   clean[key] = (value[key] as? Bool) ?? (key == "showTextures" || key == "showGrid")
  }
  for key in ["defaultColor", "backgroundColor"] {
   if let color = value[key] as? String,
      color.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil { clean[key] = color }
  }
  return clean
 }
}

enum FormBridgePolicy {
 static func isBundledWebURL(_ url: URL, root: URL?) -> Bool {
  guard url.isFileURL, let root else { return false }
  let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
  let path = url.standardizedFileURL.resolvingSymlinksInPath().path
  return path.hasPrefix(rootPath + "/")
 }
 static func acceptsMessage(source: URL?, root: URL?, isMainFrame: Bool, isViewerWebView: Bool) -> Bool {
  guard isMainFrame, isViewerWebView, let source, let root,
        isBundledWebURL(source, root: root) else { return false }
  return source.standardizedFileURL.resolvingSymlinksInPath().path == root.appendingPathComponent("index.html").standardizedFileURL.resolvingSymlinksInPath().path
 }
}

/// Main-thread coordinator, decoupled from AppKit so tests exercise the real queue logic.
final class FormImportQueue {
 typealias Read = (URL, @escaping (Result<Data, Error>) -> Void) -> Void
 typealias ImportData = (URL, Data, @escaping (Result<Bool, Error>) -> Void) -> Void
 typealias PresentError = (Error, @escaping () -> Void) -> Void
 private enum Phase { case idle, reading, importing, waitingForError }
 private let read: Read
 private let importData: ImportData
 private let didImport: (URL) -> Void
 private let presentError: PresentError
 private var pending: [URL] = []
 private var phase: Phase = .idle
 private var operation: UInt64 = 0
 private(set) var isReady = false
 var isProcessing: Bool { phase != .idle }
 var pendingCount: Int { pending.count }

 init(read: @escaping Read, importData: @escaping ImportData, didImport: @escaping (URL) -> Void, presentError: @escaping PresentError) {
  self.read = read
  self.importData = importData
  self.didImport = didImport
  self.presentError = presentError
 }
 func enqueue(_ url: URL) { pending.append(url); advance() }
 func setReady() { guard !isReady else { return }; isReady = true; advance() }

 private func advance() {
  guard isReady, phase == .idle, !pending.isEmpty else { return }
  let url = pending.removeFirst()
  operation &+= 1
  let token = operation
  phase = .reading
  read(url) { [weak self] result in
   guard let self, self.operation == token, self.phase == .reading else { return }
   switch result {
   case .failure(let error): self.fail(error, token: token)
   case .success(let data):
    self.phase = .importing
    self.importData(url, data) { [weak self] result in
     guard let self, self.operation == token, self.phase == .importing else { return }
     switch result {
     case .failure(let error): self.fail(error, token: token)
     case .success(let imported):
      if imported { self.didImport(url) }
      self.phase = .idle
      self.advance()
     }
    }
   }
  }
 }
 private func fail(_ error: Error, token: UInt64) {
  phase = .waitingForError
  presentError(error) { [weak self] in
   guard let self, self.operation == token, self.phase == .waitingForError else { return }
   self.phase = .idle
   self.advance()
  }
 }
}

enum FormBuildCapabilities {
 #if FORM_APP_STORE
 static let externalSliceEstimate = false
 static let blenderImport = false
 static let donations = false
 #else
 static let externalSliceEstimate = true
 static let blenderImport = true
 static let donations = true
 #endif
 static var dictionary: [String: Bool] { ["externalSliceEstimate": externalSliceEstimate, "blenderImport": blenderImport, "donations": donations] }
}

struct FormExternalApplication {
 let url: URL
 let bundleID: String
 let name: String
 let registeredForFile: Bool
}

enum FormExternalAppPolicy {
 static let blenderID = "org.blenderfoundation.blender"
 static let slicerIDs = ["com.bambulab.bambu-studio", "com.orcaslicer.OrcaSlicer", "com.softfever3d.orca-slicer", "com.prusa3d.slic3r", "nl.ultimaker.cura"]
 static func isSlicer(_ id: String) -> Bool { slicerIDs.contains { $0.lowercased() == id.lowercased() } }
 static let knownIDs = slicerIDs + ["com.bambulab.bambu-studio", "com.autodesk.fusion360", "com.autodesk.mas.fusion360", blenderID, "com.opencascade.CADAssistant", "org.opencascade.cadassistant"]
 static func compatible(_ application: FormExternalApplication, fileExtension: String) -> Bool {
  let ext = fileExtension.lowercased()
  guard FormImportPolicy.supportedExtensions.contains(ext) else { return false }
  switch application.bundleID.lowercased() {
  case blenderID: return FormBuildCapabilities.blenderImport && ["stl", "obj", "ply", "glb", "gltf"].contains(ext)
  case "com.bambulab.bambu-studio": return ["stl", "obj", "step", "stp", "3mf"].contains(ext)
  case "com.autodesk.fusion360", "com.autodesk.mas.fusion360": return ["stl", "obj", "step", "stp", "iges", "igs", "3mf"].contains(ext)
  case "com.opencascade.cadassistant", "org.opencascade.cadassistant": return FormImportPolicy.supportedExtensions.contains(ext)
  default: return application.registeredForFile
  }
 }
 static func filtered(_ candidates: [FormExternalApplication], fileExtension: String, ownBundleID: String?) -> [FormExternalApplication] {
  var seen = Set<String>()
  return candidates.filter { app in
   let id = app.bundleID.lowercased()
   let components = app.url.standardizedFileURL.resolvingSymlinksInPath().pathComponents.map { $0.lowercased() }
   let excluded = components.contains { ["build", ".build", "deriveddata", "archives", "archive", ".trash"].contains($0) || $0.hasSuffix(".xcarchive") }
   guard app.url.isFileURL, app.url.pathExtension.lowercased() == "app", !id.isEmpty,
    id != ownBundleID?.lowercased(), !["de.fdmwerk.form", "de.moinwerk.form"].contains(id), !excluded,
    compatible(app, fileExtension: fileExtension) else { return false }
   return seen.insert(id).inserted
  }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
 }
 #if !FORM_APP_STORE
 static func blenderArguments(script: URL, file: URL) -> [String]? {
  let app = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/Blender.app"), bundleID: blenderID, name: "Blender", registeredForFile: false)
  guard script.isFileURL, file.isFileURL, compatible(app, fileExtension: file.pathExtension) else { return nil }
  return ["--python", script.path, "--", file.path]
 }
 // File paths travel only as argv after --, never as executable Python source.
 static let blenderScript = """
 import bpy
 import os
 import sys
 args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
 if len(args) != 1:
     raise RuntimeError('Expected one model path')
 path = os.path.abspath(args[0])
 ext = os.path.splitext(path)[1].lower()
 if ext not in {'.stl', '.obj', '.ply', '.glb', '.gltf'}:
     raise RuntimeError('Unsupported model format')
 bpy.ops.wm.read_factory_settings(use_empty=True)
 if ext == '.stl':
     if bpy.app.version >= (4, 1, 0):
         bpy.ops.wm.stl_import(filepath=path)
     else:
         bpy.ops.preferences.addon_enable(module='io_mesh_stl')
         bpy.ops.import_mesh.stl(filepath=path)
 elif ext == '.obj':
     if bpy.app.version >= (4, 0, 0):
         bpy.ops.wm.obj_import(filepath=path)
     else:
         bpy.ops.preferences.addon_enable(module='io_scene_obj')
         bpy.ops.import_scene.obj(filepath=path)
 elif ext == '.ply':
     if bpy.app.version >= (4, 0, 0):
         bpy.ops.wm.ply_import(filepath=path)
     else:
         bpy.ops.preferences.addon_enable(module='io_mesh_ply')
         bpy.ops.import_mesh.ply(filepath=path)
 else:
     bpy.ops.import_scene.gltf(filepath=path)
 for area in bpy.context.screen.areas if bpy.context.screen else []:
     if area.type == 'VIEW_3D':
         region = next((r for r in area.regions if r.type == 'WINDOW'), None)
         if region:
             with bpy.context.temp_override(area=area, region=region):
                 bpy.ops.view3d.view_all(center=False)
 """
 #endif
}

/// Per-session origin identity: filenames are intentionally never used as lookup keys.
final class FormSourceRegistry {
 private var urls: [String: URL] = [:]
 func record(_ sourceID: String, url: URL, imported: Bool) {
  guard imported, UUID(uuidString: sourceID) != nil, url.isFileURL else { return }
  urls[sourceID] = url
 }
 func sourceURL(for value: Any?) -> URL? {
  guard let sourceID = value as? String, sourceID.count == 36 else { return nil }
  return urls[sourceID]
 }
}

/// One short-lived local process with explicit cancellation and a hard deadline.
#if !FORM_APP_STORE
final class FormBoundedProcess {
 enum Outcome: Equatable { case exited(Int32), cancelled, timedOut }
 private let lock = NSLock()
 private var process: Process?
 private var cancelled = false
 private var timedOut = false
 func cancel() {
  lock.lock(); cancelled = true; let active = process; lock.unlock()
  if let active { stop(active) }
 }
 private func stop(_ task: Process) {
  guard task.isRunning else { return }
  task.terminate()
  DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
   if task.isRunning { kill(task.processIdentifier, SIGKILL) }
  }
 }
 func run(executable: URL, arguments: [String], timeout: TimeInterval) throws -> Outcome {
  let task = Process()
  task.executableURL = executable
  task.arguments = arguments
  task.standardOutput = FileHandle.nullDevice
  task.standardError = FileHandle.nullDevice
  lock.lock()
  if cancelled { lock.unlock(); return .cancelled }
  process = task
  do { try task.run() } catch { process = nil; lock.unlock(); throw error }
  lock.unlock()
  let deadline = DispatchWorkItem { [weak self, weak task] in
   guard let self, let task else { return }
   self.lock.lock()
   guard self.process === task else { self.lock.unlock(); return }
   self.timedOut = true
   self.lock.unlock()
   self.stop(task)
  }
  DispatchQueue.global().asyncAfter(deadline: .now() + max(0.05, timeout), execute: deadline)
  task.waitUntilExit()
  deadline.cancel()
  lock.lock(); process = nil
  let outcome: Outcome = timedOut ? .timedOut : (cancelled ? .cancelled : .exited(task.terminationStatus))
  lock.unlock()
  return outcome
 }
}

#endif

struct FormSliceRequest {
 let requestID: String
 let sourceID: String
 let material: String
 let scale: Double
}

enum FormSliceRequestPolicy {
 static func parse(_ message: [String: Any]) -> FormSliceRequest? {
  // Request IDs correlate callbacks; they are opaque, bounded strings rather than security credentials.
  guard let requestID = message["requestID"] as? String, !requestID.isEmpty, requestID.utf8.count <= 128,
    let sourceID = message["sourceID"] as? String, UUID(uuidString: sourceID) != nil,
    let material = message["material"] as? String, FormBambuSlicePolicy.materialName(material) != nil else { return nil }
  let scale = (message["scale"] as? NSNumber)?.doubleValue ?? 1
  guard scale.isFinite, scale > 0, scale <= 1000 else { return nil }
  return FormSliceRequest(requestID: requestID, sourceID: sourceID, material: material, scale: scale)
 }
 static func error(_ message: [String: Any], code: String) -> [String: Any] {
  ["requestID": message["requestID"] as? String ?? "", "sourceID": message["sourceID"] as? String ?? "", "state": "error", "errorCode": code]
 }
 static func source(_ request: FormSliceRequest, selected: Any?, registry: FormSourceRegistry) -> URL? {
  guard let selected = selected as? String, selected == request.sourceID else { return nil }
  return registry.sourceURL(for: selected)
 }
}

enum FormBambuSlicePolicy {
 enum Failure: Error { case unsupported, unavailable, preset, failed, timeout, cancelled }
 static let machineName = "Bambu Lab A1 mini 0.4 nozzle"
 static let processName = "0.20mm Standard @BBL A1M"
 static func materialName(_ material: String) -> String? {
  ["PLA": "Generic PLA @BBL A1M", "PETG": "Generic PETG @BBL A1M"][material]
 }
 static func mergedPreset(_ name: String, index: [String: [String: Any]], visited: Set<String> = []) throws -> [String: Any] {
  guard visited.count < 32, !visited.contains(name), let current = index[name] else { throw Failure.preset }
  var visited = visited; visited.insert(name)
  var output: [String: Any] = [:]
  if let parent = current["inherits"] as? String, !parent.isEmpty { output.merge(try mergedPreset(parent, index: index, visited: visited)) { _, latest in latest } }
  for include in current["include"] as? [String] ?? [] { output.merge(try mergedPreset(include, index: index, visited: visited)) { _, latest in latest } }
  output.merge(current) { _, latest in latest }
  output.removeValue(forKey: "inherits"); output.removeValue(forKey: "include")
  return output
 }
 static func readPresetIndex(_ root: URL) throws -> [String: [String: Any]] {
  guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { throw Failure.preset }
  var output: [String: [String: Any]] = [:]
  var count = 0, totalBytes = 0
  for case let url as URL in files where url.pathExtension == "json" {
   count += 1
   guard count <= 5000, url.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/"),
     (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else { throw Failure.preset }
   let data = try Data(contentsOf: url)
   totalBytes += data.count
   guard data.count <= 2_000_000, totalBytes <= 50_000_000,
     let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.preset }
   output[url.deletingPathExtension().lastPathComponent] = object
   if let name = object["name"] as? String { output[name] = object }
  }
  return output
 }
 static func result(_ data: Data) throws -> (seconds: Double, grams: Double) {
  guard data.count <= 1_000_000, let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    result["return_code"] as? Int == 0,
    let plates = result["sliced_plates"] as? [[String: Any]], plates.count == 1,
    let seconds = plates[0]["total_predication"] as? Double, seconds.isFinite, seconds > 0, seconds < 31_536_000,
    let filaments = plates[0]["filaments"] as? [[String: Any]], !filaments.isEmpty else { throw Failure.failed }
  let values = filaments.compactMap { $0["total_used_g"] as? Double }
  guard values.count == filaments.count, values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 < 1_000_000 }) else { throw Failure.failed }
  return (seconds, values.reduce(0, +))
 }
 #if !FORM_APP_STORE
 static func estimate(application: URL, source: URL, material: String, scale: Double, control: FormBoundedProcess) throws -> (seconds: Double, grams: Double) {
  guard source.pathExtension.lowercased() == "stl", let filamentName = materialName(material),
    scale.isFinite, scale > 0, scale <= 1000 else { throw Failure.unsupported }
  let root = application.appendingPathComponent("Contents/Resources/profiles/BBL")
  let index = try readPresetIndex(root)
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FormSlice-" + UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let output = directory.appendingPathComponent("output", isDirectory: true)
  try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
  for (type, name) in [("machine", machineName), ("process", processName), ("filament", filamentName)] {
   var preset = try mergedPreset(name, index: index)
   if type == "process" { preset["curr_bed_type"] = "Textured PEI Plate" }
   try JSONSerialization.data(withJSONObject: preset).write(to: directory.appendingPathComponent(type + ".json"), options: .atomic)
  }
  // Copy only an explicitly imported original; never modify it or consume personal slicer presets.
  let data = try FormImportPolicy.read(source)
  let input = directory.appendingPathComponent("input.stl")
  try data.write(to: input, options: .atomic)
  let arguments = ["--datadir", directory.appendingPathComponent("data").path,
   "--load-settings", directory.appendingPathComponent("machine.json").path + ";" + directory.appendingPathComponent("process.json").path,
   "--load-filaments", directory.appendingPathComponent("filament.json").path,
   "--scale", String(scale), "--slice", "0", "--mstpp", "30", "--export-3mf", "estimate.3mf", "--outputdir", output.path, input.path]
  switch try control.run(executable: application.appendingPathComponent("Contents/MacOS/BambuStudio"), arguments: arguments, timeout: 40) {
  case .cancelled: throw Failure.cancelled
  case .timedOut: throw Failure.timeout
  case .exited(let status): guard status == 0 else { throw Failure.failed }
  }
  return try result(Data(contentsOf: output.appendingPathComponent("result.json")))
 }
 #endif
}

#if !FORM_APP_STORE
enum FormSupportPolicy {
 static var donationURL: URL {
  var url = URLComponents(string: "https://www.paypal.com/cgi-bin/webscr")!
  url.queryItems = [URLQueryItem(name: "cmd", value: "_donations"),
   URLQueryItem(name: "business", value: "christoph@moinwerk.com"),
   URLQueryItem(name: "currency_code", value: "EUR"),
   URLQueryItem(name: "item_name", value: "Support Form CAD Viewer")]
  return url.url!
 }
}
#endif

enum FormFeedbackPolicy {
 static var emailURL: URL {
  var url = URLComponents(string: "mailto:support@fdmwerk.de")!
  url.queryItems = [URLQueryItem(name: "subject", value: "Form – Feature request")]
  return url.url!
 }
 static let githubURL = URL(string: "https://github.com/FDMwerk/Form/issues/new?template=feature_request.yml")!
}
