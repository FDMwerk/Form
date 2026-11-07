import Foundation
import ImageIO

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
  for key in ["reverseZoom", "trackpad", "componentColors", "showTextures"] {
   clean[key] = (value[key] as? Bool) ?? (key == "showTextures")
  }
  if let color = value["defaultColor"] as? String,
     color.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil { clean["defaultColor"] = color }
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
