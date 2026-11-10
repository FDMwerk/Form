import XCTest
import UIKit
@testable import FormMobile

@MainActor
final class NativePanelTests: XCTestCase {
    func testSwitchEmitsTypedValueAndDisabledButtonDoesNothing() {
        var events: [(String,Any?)] = []
        let panel = NativePanelController(title:"Settings",sections:[["items":[
            ["id":"grid","title":"Grid","kind":"toggle","value":true],
            ["id":"remove","title":"Remove","kind":"button","enabled":false]
        ]]]) { events.append(($0,$1)) }
        panel.loadViewIfNeeded()
        let cell = panel.tableView(panel.tableView,cellForRowAt:IndexPath(row:0,section:0))
        let control = cell.accessoryView as? UISwitch
        XCTAssertEqual(control?.isOn,true)
        control?.isOn=false; control?.sendActions(for:.valueChanged)
        XCTAssertEqual(events.count,1)
        XCTAssertEqual(events.first?.0,"grid")
        XCTAssertEqual(events.first?.1 as? Bool,false)
        panel.tableView(panel.tableView,didSelectRowAt:IndexPath(row:1,section:0))
        XCTAssertEqual(events.count,1)
    }

    func testSliderQuantizesAndPreservesActiveGestureDuringStateUpdates() throws {
        var received: Double?
        func sections(_ value:Double)->[[String:Any]] {[["items":[["id":"cut-value","title":"Offset","kind":"range","min":0,"max":100,"step":5,"value":value]]]]}
        let panel = NativePanelController(title:"Section",sections:sections(20)) { _,value in received=value as? Double }
        panel.loadViewIfNeeded()
        let path=IndexPath(row:0,section:0)
        let cell=panel.tableView(panel.tableView,cellForRowAt:path)
        let slider=try XCTUnwrap(find(UISlider.self,in:cell))
        slider.sendActions(for:.touchDown)
        slider.value=32; slider.sendActions(for:.valueChanged)
        XCTAssertEqual(try XCTUnwrap(received),30,accuracy:1e-9)
        XCTAssertEqual(slider.value,30,accuracy:0.0001)
        panel.update(sections:sections(75))
        let whileEditing=panel.tableView(panel.tableView,cellForRowAt:path)
        XCTAssertEqual(try XCTUnwrap(find(UISlider.self,in:whileEditing)).value,20,accuracy:0.0001,"Incoming state must wait while a real slider gesture is active")
        slider.sendActions(for:.touchUpInside)
        let afterEditing=panel.tableView(panel.tableView,cellForRowAt:path)
        XCTAssertEqual(try XCTUnwrap(find(UISlider.self,in:afterEditing)).value,75,accuracy:0.0001)
    }

    func testSelectionMenuUsesCurrentRendererValueAndRetainsLongLabels() throws {
        let panel=NativePanelController(title:"View",sections:[["items":[["id":"projection","title":"Projection","kind":"select","value":"orthographic","options":[["value":"perspective","title":"Perspective"],["value":"orthographic","title":"Orthographic"]]]]]]) { _,_ in }
        panel.loadViewIfNeeded()
        let cell=panel.tableView(panel.tableView,cellForRowAt:IndexPath(row:0,section:0))
        let button=try XCTUnwrap(cell.accessoryView as? UIButton)
        let options=try XCTUnwrap(button.menu?.children as? [UIAction])
        XCTAssertEqual(options.map(\.state),[.off,.on])
        XCTAssertEqual(button.accessibilityValue,"Orthographic")
        XCTAssertEqual(button.accessibilityIdentifier,"native.panel.projection")
    }

    private func find<T:UIView>(_ type:T.Type,in view:UIView)->T? {
        if let result=view as? T {return result}
        for child in view.subviews {if let result=find(type,in:child) {return result}}
        return nil
    }
}
