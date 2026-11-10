import XCTest
import WebKit
import CryptoKit
@testable import FormMobile

/// Hosted tests drive the production native entry points and inspect both UIKit and
/// renderer state. A visible mesh alone must never count as a successful import.
@MainActor final class MobileTests: XCTestCase {
    @MainActor private struct Host {
        let window: UIWindow
        let previous: UIWindow?
        let workspace: MobileWorkspaceController
        var viewer: MobileViewerController { workspace.viewer }
        func close() { window.isHidden = true; previous?.makeKeyAndVisible() }
    }
    private func makeHost() throws -> Host {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let workspace = MobileWorkspaceController()
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds; window.rootViewController = workspace
        window.makeKeyAndVisible(); workspace.loadViewIfNeeded(); workspace.viewer.loadViewIfNeeded()
        return Host(window: window, previous: previous, workspace: workspace)
    }
    private func waitUntil(seconds: TimeInterval = 20, _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return condition()
    }
    private func rows(_ viewer: MobileViewerController) -> [[String: Any]] {
        (viewer.latestState["sidebar"] as? [String: Any])?["rows"] as? [[String: Any]] ?? []
    }
    private func models(_ viewer: MobileViewerController) -> [[String: Any]] {
        rows(viewer).filter { $0["kind"] as? String == "model" }
    }
    private func capture(_ host: Host, name: String, assertGeometry: Bool = false) async throws {
        host.window.layoutIfNeeded(); host.viewer.view.layoutIfNeeded()
        let geometry = try await host.viewer.web.evaluateJavaScript("(()=>{const r=document.getElementById('canvas').getBoundingClientRect();return {innerWidth,innerHeight,dpr:devicePixelRatio,canvas:{x:r.x,y:r.y,width:r.width,height:r.height},documentWidth:document.documentElement.clientWidth,documentHeight:document.documentElement.clientHeight,scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight}})()") as? [String: Any] ?? [:]
        let webFrame = host.viewer.web.frame, safeFrame = host.viewer.view.safeAreaLayoutGuide.layoutFrame
        let rect: (CGRect) -> [String: Double] = { ["x": Double($0.minX), "y": Double($0.minY), "width": Double($0.width), "height": Double($0.height)] }
        let diagnostic: [String: Any] = ["renderer": geometry, "webFrame": rect(webFrame), "webBounds": rect(host.viewer.web.bounds), "viewerBounds": rect(host.viewer.view.bounds), "viewerSafeFrame": rect(safeFrame), "windowBounds": rect(host.window.bounds)]
        let diagnosticData = try JSONSerialization.data(withJSONObject: diagnostic, options: [.prettyPrinted, .sortedKeys])
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try diagnosticData.write(to: cache.appendingPathComponent("FormMobile-\(name)-Geometry-\(device).json"))
        let diagnosticAttachment = XCTAttachment(data: diagnosticData, uniformTypeIdentifier: "public.json"); diagnosticAttachment.name = name + " viewport geometry"; diagnosticAttachment.lifetime = .keepAlways; add(diagnosticAttachment)
        if assertGeometry {
            XCTAssertEqual(webFrame.minX, safeFrame.minX, accuracy: 1)
            XCTAssertEqual(webFrame.minY, safeFrame.minY, accuracy: 1)
            XCTAssertEqual(webFrame.width, safeFrame.width, accuracy: 1)
            XCTAssertEqual(webFrame.height, safeFrame.height, accuracy: 1)
            let canvas = try XCTUnwrap(geometry["canvas"] as? [String: Any])
            let width = try XCTUnwrap(geometry["innerWidth"] as? Double), height = try XCTUnwrap(geometry["innerHeight"] as? Double)
            XCTAssertEqual(width, Double(host.viewer.web.bounds.width), accuracy: 1, "Web viewport must match actual native renderer width")
            XCTAssertEqual(height, Double(host.viewer.web.bounds.height), accuracy: 1, "Web viewport must match actual native renderer height")
            XCTAssertEqual(try XCTUnwrap(canvas["x"] as? Double), 0, accuracy: 1, "Canvas must not retain a hidden desktop sidebar offset")
            XCTAssertEqual(try XCTUnwrap(canvas["y"] as? Double), 0, accuracy: 1)
            XCTAssertEqual(try XCTUnwrap(canvas["width"] as? Double), width, accuracy: 1)
            XCTAssertEqual(try XCTUnwrap(canvas["height"] as? Double), height, accuracy: 1)
        }
        let image = UIGraphicsImageRenderer(bounds: host.window.bounds).image { _ in
            host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        try image.pngData()?.write(to: cache.appendingPathComponent("FormMobile-\(name)-\(device).png"))
    }
    private func openExample(_ host: Host) async throws {
        let ready = await waitUntil { host.viewer.ready }
        XCTAssertTrue(ready, "The actual native workspace must finish renderer startup")
        guard ready else { throw CocoaError(.fileReadUnknown) }
        host.viewer.performMobileCommand("openExample")
        let committed = await waitUntil {
            host.viewer.latestState["title"] as? String == "3DBenchy.stl" && host.viewer.navigationItem.title == "3DBenchy.stl" && !self.models(host.viewer).isEmpty
        }
        XCTAssertTrue(committed, "Import must update the native state, title and model tree, not only paint a mesh")
        guard committed else { throw CocoaError(.fileReadUnknown) }
    }

    func testFilePolicyRejectsWebpagesAndUnknownFiles() {
        XCTAssertFalse(MobileFilePolicy.accepts(URL(string: "https://makerworld.com/model.stl")!))
        XCTAssertFalse(MobileFilePolicy.accepts(URL(fileURLWithPath: "/tmp/file.html")))
        XCTAssertTrue(MobileFilePolicy.accepts(URL(fileURLWithPath: "/tmp/PART.STL")))
        XCTAssertTrue(MobileFilePolicy.accepts(URL(fileURLWithPath: "/tmp/part.3mf")))
    }

    func testOriginalBenchyNativeImportStaysSynchronizedDuringRenderUpdates() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "3DBenchy", withExtension: "stl", subdirectory: "Examples"))
        let digest = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "fd99f33201b2d0ca60de7973748e489f813452f91b511a661548eee50370f3eb")
        let host = try makeHost(); defer { host.close() }
        let ready = await waitUntil { host.viewer.ready }; XCTAssertTrue(ready)
        XCTAssertNotNil(host.viewer.contentUnavailableConfiguration, "Empty workspace must use the native Apple empty-state component")
        // This is the production starvation condition: RAF repeatedly changes an
        // observed ARIA attribute, without changing import metadata semantically.
        _ = try await host.viewer.web.evaluateJavaScript("window.__nativeStateHeartbeat=setInterval(()=>document.getElementById('fit').setAttribute('aria-pressed','false'),16)")
        defer { host.viewer.web.evaluateJavaScript("clearInterval(window.__nativeStateHeartbeat)", completionHandler: nil) }
        host.viewer.performMobileCommand("openExample")
        let committed = await waitUntil(seconds: 12) {
            host.viewer.latestState["title"] as? String == "3DBenchy.stl" && host.viewer.navigationItem.title == "3DBenchy.stl" && !self.models(host.viewer).isEmpty
        }
        XCTAssertTrue(committed, "Native state delivery must not starve while render updates continue")
        XCTAssertEqual(host.viewer.navigationItem.title, "3DBenchy.stl")
        XCTAssertEqual(host.viewer.latestState["hasModels"] as? Bool, true)
        let sourceID = try XCTUnwrap(host.viewer.latestState["selectedSourceID"] as? String)
        let sourceRegistered = await waitUntil(seconds: 3) { host.viewer.sourceURL(for: sourceID) != nil }
        XCTAssertTrue(sourceRegistered, "Committed renderer identity must be registered for native sharing")
        let sourceURL = try XCTUnwrap(host.viewer.sourceURL(for: sourceID))
        XCTAssertEqual(sourceURL.lastPathComponent, "3DBenchy.stl", "Sharing must resolve the imported native file identity")
        let nativeSidebarReady = await waitUntil { self.rows(host.viewer).contains { $0["name"] as? String == "3DBenchy" } }
        XCTAssertTrue(nativeSidebarReady)
        host.viewer.modelSidebar.loadViewIfNeeded()
        XCTAssertGreaterThanOrEqual(host.viewer.modelSidebar.collectionView(host.viewer.modelSidebar.collectionView, numberOfItemsInSection: 1), 2)
        let rendererTitle = try await host.viewer.web.evaluateJavaScript("document.getElementById('filename').textContent") as? String
        XCTAssertEqual(rendererTitle, host.viewer.navigationItem.title)
        let controls = host.viewer.latestState["controls"] as? [String: [String: Any]]
        XCTAssertEqual(controls?["measure"]?["enabled"] as? Bool, true)
        XCTAssertEqual(controls?["info"]?["enabled"] as? Bool, true)
        try await Task.sleep(nanoseconds: 200_000_000)
        try await capture(host, name: "Redesign-Benchy", assertGeometry: true)
    }

    func testQueuedImportsAndNativeSidebarActionsUseTheSameModels() async throws {
        let host = try makeHost(); defer { host.close() }
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
        // Queue before renderer readiness. A failed middle import must not stall
        // native metadata updates or prevent the second valid file appearing.
        host.viewer.enqueue([a, invalid, b])
        let imported = await waitUntil {
            let names = self.models(host.viewer).compactMap { $0["name"] as? String }
            return names.contains("First") && names.contains("Second")
        }
        XCTAssertTrue(imported)
        XCTAssertEqual(models(host.viewer).filter { $0["depth"] as? Int == 0 }.count, 2)
        let row = try XCTUnwrap(models(host.viewer).first { $0["name"] as? String == "First" })
        let id = try XCTUnwrap(row["id"] as? String)
        // Drive the callback used by the native collection-view gestures.
        host.viewer.modelSidebar.command?("visibility", id, false)
        let hidden = await waitUntil { self.models(host.viewer).first { $0["id"] as? String == id }?["visible"] as? Bool == false }
        XCTAssertTrue(hidden)
        host.viewer.modelSidebar.command?("visibility", id, false)
        let visible = await waitUntil { self.models(host.viewer).first { $0["id"] as? String == id }?["visible"] as? Bool == true }
        XCTAssertTrue(visible)
        host.viewer.modelSidebar.command?("select", "all", false)
        let all = await waitUntil { self.rows(host.viewer).first { $0["id"] as? String == "all" }?["selected"] as? Bool == true }
        XCTAssertTrue(all)
        host.viewer.modelSidebar.command?("remove", id, false)
        let removed = await waitUntil { !self.models(host.viewer).contains { $0["id"] as? String == id } }
        XCTAssertTrue(removed)
        XCTAssertEqual(host.viewer.latestState["modelCount"] as? Int, 1)
        XCTAssertTrue(models(host.viewer).contains { $0["name"] as? String == "Second" }, "Unloading one file must retain the other native row and model")
    }

    func testNativePanelsAndAdaptiveWorkspaceRetainRendererControls() async throws {
        let host = try makeHost(); defer { host.close() }
        try await openExample(host)
        let panels = try XCTUnwrap(host.viewer.latestState["panels"] as? [String: [String: Any]])
        XCTAssertFalse(panels.isEmpty)
        // Exercise the actual toolbar/sidebar routes, not only descriptor keys.
        // Missing aliases previously allowed a valid descriptor test to conceal a
        // toolbar button which opened no editor at all.
        let routes: [(String, String?)] = [
            ("display", "display-menu"), ("background", "background-menu"),
            ("appearance", "scene-settings"), ("settings", "settings"),
            ("position", "model-tools"), ("explode", "explode"),
            ("measure", nil), ("cut", nil), ("print", nil)
        ]
        for (key, command) in routes {
            XCTAssertNotNil(panels[key], "Missing production native panel descriptor: " + key)
            if let command { host.viewer.performMobileCommand(command) }
            else { host.viewer.showPanel(key) }
            let presented = await waitUntil(seconds: 3) {
                (host.viewer.presentedViewController as? UINavigationController)?.topViewController is NativePanelController
            }
            XCTAssertTrue(presented, "Expected native editor through production route for \(key)")
            guard let nav = host.viewer.presentedViewController as? UINavigationController,
                  let panel = nav.topViewController as? NativePanelController else { continue }
            panel.loadViewIfNeeded()
            let count = (0..<panel.numberOfSections(in: panel.tableView)).reduce(0) { $0 + panel.tableView(panel.tableView, numberOfRowsInSection: $1) }
            XCTAssertGreaterThan(count, 0, key)
            try await Task.sleep(nanoseconds: 300_000_000)
            if key == "settings" { try await capture(host, name: "Redesign-Settings") }
            host.viewer.dismiss(animated: false)
            let closed = await waitUntil(seconds: 3) { host.viewer.presentedViewController == nil }
            XCTAssertTrue(closed, "Each native editor must dismiss before returning to the viewer")
        }
        host.viewer.performMobileCommand("measure")
        let measuring = await waitUntil {
            ((host.viewer.latestState["controls"] as? [String: [String: Any]])?["measure"]?["active"] as? Bool) == true
        }
        XCTAssertTrue(measuring, "The native ruler button must activate the renderer's actual measuring tool")
        host.viewer.performMobileCommand("measure")
        let stopped = await waitUntil {
            ((host.viewer.latestState["controls"] as? [String: [String: Any]])?["measure"]?["active"] as? Bool) == false
        }
        XCTAssertTrue(stopped)
        let overlayVisible = try await host.viewer.web.evaluateJavaScript("[...document.querySelectorAll('header,body>aside,#tool-panels,#viewport-display-controls,#view-navigator')].some(e=>getComputedStyle(e).display!=='none' && e.getBoundingClientRect().width>0)") as? Bool
        XCTAssertEqual(overlayVisible, false, "The native product must not leave desktop interaction chrome on screen")
        let fits = try await host.viewer.web.evaluateJavaScript("document.documentElement.scrollWidth <= innerWidth") as? Bool
        XCTAssertEqual(fits, true)
        host.viewer.showFileInformation()
        let infoPresented = await waitUntil(seconds: 3) { host.viewer.presentedViewController != nil }
        XCTAssertTrue(infoPresented)
        let infoNavigation = try XCTUnwrap(host.viewer.presentedViewController as? UINavigationController)
        let information = try XCTUnwrap(infoNavigation.topViewController as? FileInformationController)
        information.loadViewIfNeeded()
        XCTAssertGreaterThan(information.numberOfSections(in: information.tableView), 0)
        try await capture(host, name: "Redesign-Information")
        host.viewer.dismiss(animated: false)
        // Adaptive split view is the actual workspace, not a hand-positioned web sidebar.
        XCTAssertEqual(host.workspace.style, .doubleColumn)
    }
}
