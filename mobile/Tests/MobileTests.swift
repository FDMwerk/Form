import XCTest
import WebKit
@testable import FormMobile

@MainActor final class MobileTests: XCTestCase {
    func testFilePolicyRejectsWebpagesAndUnknownFiles() {
        XCTAssertFalse(MobileFilePolicy.accepts(URL(string: "https://makerworld.com/model.stl")!))
        XCTAssertFalse(MobileFilePolicy.accepts(URL(fileURLWithPath: "/tmp/file.html")))
        XCTAssertTrue(MobileFilePolicy.accepts(URL(fileURLWithPath: "/tmp/PART.STL")))
        XCTAssertTrue(MobileFilePolicy.accepts(URL(fileURLWithPath: "/tmp/part.3mf")))
    }
    func testRealWebKitImportsQueuedModelsAndRecoversFromInvalidMesh() async throws {
        let controller = MobileViewerController()
        let host = UIWindow(frame: UIScreen.main.bounds)
        host.rootViewController = controller; host.makeKeyAndVisible()
        defer { host.isHidden = true }
        controller.loadViewIfNeeded()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stl = """
        solid triangle
        facet normal 0 0 1
        outer loop
        vertex 0 0 0
        vertex 30 0 0
        vertex 0 30 10
        endloop
        endfacet
        endsolid triangle
        """
        let a = directory.appendingPathComponent("First.stl"), b = directory.appendingPathComponent("Second.stl")
        let invalid = directory.appendingPathComponent("Invalid.stl")
        try Data(stl.utf8).write(to: a); try Data(stl.utf8).write(to: b)
        try Data("not a mesh".utf8).write(to: invalid)
        // Queue before WebKit is ready; a failed intermediate model must not stall the queue.
        controller.enqueue([a, invalid, b])
        var imported = false
        for _ in 0..<180 {
            try await Task.sleep(nanoseconds: 250_000_000)
            if controller.ready, let value = try? await controller.web.evaluateJavaScript("document.querySelector('#parts').textContent") as? String,
               value.contains("First"), value.contains("Second") { imported = true; break }
        }
        XCTAssertTrue(imported, "Both models must import through the real native→WebKit bridge")
        let mobile = try await controller.web.evaluateJavaScript("document.documentElement.dataset.formMobile === 'true'") as? Bool
        XCTAssertEqual(mobile, true)
        let overflow = try await controller.web.evaluateJavaScript("document.documentElement.scrollWidth > innerWidth") as? Bool
        XCTAssertEqual(overflow, false, "Mobile viewport must not overflow horizontally")
        let image = try await controller.web.takeSnapshot(configuration: nil)
        let attachment = XCTAttachment(image: image); attachment.name = "Form Mobile imported models"; attachment.lifetime = .keepAlways; add(attachment)
        let screenshot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("FormMobile-\(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone").png")
        try image.pngData()?.write(to: screenshot)
    }
}
