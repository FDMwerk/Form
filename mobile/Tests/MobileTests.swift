import XCTest
import WebKit
import CryptoKit
@testable import FormMobile

@MainActor final class MobileTests: XCTestCase {
    func testBundledBenchyMatchesOriginalAndLoadsThroughExampleButton() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "3DBenchy", withExtension: "stl", subdirectory: "Examples"))
        let digest = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "fd99f33201b2d0ca60de7973748e489f813452f91b511a661548eee50370f3eb")
        let controller = MobileViewerController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let host = UIWindow(windowScene: scene); host.frame = scene.coordinateSpace.bounds; host.rootViewController = controller; host.makeKeyAndVisible()
        defer { host.isHidden = true }
        controller.loadViewIfNeeded()
        for _ in 0..<180 { if controller.ready { break }; try await Task.sleep(nanoseconds: 250_000_000) }
        XCTAssertTrue(controller.ready)
        let buttonCount = try await controller.web.evaluateJavaScript("document.querySelectorAll('.mobile-example').length") as? Int
        XCTAssertEqual(buttonCount, 2)
        _ = try await controller.web.evaluateJavaScript("document.querySelector('.mobile-example').click()")
        var loaded = false
        for _ in 0..<180 {
            try await Task.sleep(nanoseconds: 250_000_000)
            if let filename = try? await controller.web.evaluateJavaScript("document.getElementById('filename').textContent") as? String, filename == "3DBenchy.stl" { loaded = true; break }
        }
        XCTAssertTrue(loaded)
        _ = try await controller.web.evaluateJavaScript("window.applyViewportSettings({showGrid:true,backgroundColor:'#fafafa'})")
        let gridVisible = try await controller.web.evaluateJavaScript("document.getElementById('grid').classList.contains('active')") as? Bool
        XCTAssertEqual(gridVisible,true)
        let toolbar = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIToolbar }.first)
        XCTAssertNotNil(toolbar.items?.first { $0.accessibilityIdentifier == "form.measure" })
        _ = try await controller.web.evaluateJavaScript("window.formMobileCommand('measure')")
        let measuring = try await controller.web.evaluateJavaScript("document.getElementById('measure').classList.contains('active')") as? Bool
        XCTAssertEqual(measuring, true)
        _ = try await controller.web.evaluateJavaScript("window.formMobileCommand('measure');window.formMobileCommand('unit:10')")
        let unit = try await controller.web.evaluateJavaScript("document.getElementById('unit').value") as? String
        XCTAssertEqual(unit, "10")
        _ = try await controller.web.evaluateJavaScript("window.formMobileCommand('unit:1');window.formMobileCommand('scene-settings')")
        let headerDisplay = try await controller.web.evaluateJavaScript("getComputedStyle(document.querySelector('header')).display") as? String
        XCTAssertEqual(headerDisplay, "contents")
        _ = try await controller.web.evaluateJavaScript("window.formMobileCommand('scene-settings')")
        try await Task.sleep(nanoseconds: 200_000_000)
        let image = UIGraphicsImageRenderer(bounds: host.bounds).image { _ in host.drawHierarchy(in: host.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image); attachment.name = "Original 3DBenchy"; attachment.lifetime = .keepAlways; add(attachment)
        let screenshot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("FormMobile-Benchy-\(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone").png")
        try image.pngData()?.write(to: screenshot)
        for (command,panel) in [("display-menu","display-panel"),("background-menu","background-panel"),("scene-settings","scene-settings-panel")] {
            _ = try await controller.web.evaluateJavaScript("window.formMobileCommand('\(command)')")
            let opened = try await controller.web.evaluateJavaScript("!document.getElementById('\(panel)').hidden && getComputedStyle(document.getElementById('\(panel)')).display !== 'none'") as? Bool
            XCTAssertEqual(opened,true,"Panel must be visible: " + panel)
            _ = try await controller.web.evaluateJavaScript("document.getElementById('\(panel)').querySelector('.mobile-subpanel-close').click()")
            let closed = try await controller.web.evaluateJavaScript("document.getElementById('\(panel)').hidden") as? Bool
            XCTAssertEqual(closed,true)
        }
        controller.showFileInformation()
        try await Task.sleep(nanoseconds:500_000_000)
        let navigation = try XCTUnwrap(controller.presentedViewController as? UINavigationController)
        let information = try XCTUnwrap(navigation.topViewController as? FileInformationController)
        information.loadViewIfNeeded()
        XCTAssertEqual(information.numberOfSections(in:information.tableView),2)
        XCTAssertGreaterThan(information.tableView(information.tableView,numberOfRowsInSection:0),0)
        let infoImage = UIGraphicsImageRenderer(bounds:host.bounds).image { _ in host.drawHierarchy(in:host.bounds,afterScreenUpdates:true) }
        let infoURL = screenshot.deletingLastPathComponent().appendingPathComponent("FormMobile-Info-\(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone").png")
        try infoImage.pngData()?.write(to:infoURL)
        controller.dismiss(animated:false)
    }
    func testFilePolicyRejectsWebpagesAndUnknownFiles() {
        XCTAssertFalse(MobileFilePolicy.accepts(URL(string: "https://makerworld.com/model.stl")!))
        XCTAssertFalse(MobileFilePolicy.accepts(URL(fileURLWithPath: "/tmp/file.html")))
        XCTAssertTrue(MobileFilePolicy.accepts(URL(fileURLWithPath: "/tmp/PART.STL")))
        XCTAssertTrue(MobileFilePolicy.accepts(URL(fileURLWithPath: "/tmp/part.3mf")))
    }
    func testRealWebKitImportsQueuedModelsAndRecoversFromInvalidMesh() async throws {
        let controller = MobileViewerController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let host = UIWindow(windowScene: scene); host.frame = scene.coordinateSpace.bounds
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
        let overflowDetail = try await controller.web.evaluateJavaScript("JSON.stringify([...document.querySelectorAll('body *')].map(e=>({id:e.id,tag:e.tagName,right:e.getBoundingClientRect().right,left:e.getBoundingClientRect().left})).filter(r=>r.right>innerWidth+1||r.left < -1))") as? String
        XCTAssertEqual(overflow, false, "Mobile viewport overflow: \(overflowDetail ?? "unknown")")
        let image = try await controller.web.takeSnapshot(configuration: nil)
        let attachment = XCTAttachment(image: image); attachment.name = "Form Mobile imported models"; attachment.lifetime = .keepAlways; add(attachment)
        let screenshot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("FormMobile-\(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone").png")
        try image.pngData()?.write(to: screenshot)
    }
}
