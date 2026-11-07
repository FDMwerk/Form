import Foundation

@main
struct NativeStoreTests {
 static func main() {
  precondition(!FormBuildCapabilities.externalSliceEstimate && !FormBuildCapabilities.blenderImport)
  precondition(FormBuildCapabilities.dictionary == ["externalSliceEstimate": false, "blenderImport": false])
  let blender = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/Blender.app"), bundleID: FormExternalAppPolicy.blenderID, name: "Blender", registeredForFile: true)
  let bambu = FormExternalApplication(url: URL(fileURLWithPath: "/Applications/BambuStudio.app"), bundleID: "com.bambulab.bambu-studio", name: "Bambu Studio", registeredForFile: true)
  precondition(!FormExternalAppPolicy.compatible(blender, fileExtension: "stl"))
  precondition(!FormExternalAppPolicy.compatible(blender, fileExtension: "glb"))
  precondition(FormExternalAppPolicy.compatible(bambu, fileExtension: "stl"))
  let apps = FormExternalAppPolicy.filtered([blender, bambu], fileExtension: "stl", ownBundleID: "de.fdmwerk.form")
  precondition(apps.map { $0.bundleID } == [bambu.bundleID])
  print("PASS AppStore flavor: external execution capabilities off, Blender importer excluded, original-file handoff retained")
 }
}
