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

    func testContextToolbarRetainsMeasurementSettingsAndDestructiveAvailabilityInNativeMenus() throws {
        let toolbar=ContextToolbar()
        toolbar.setTool("measure")
        toolbar.update(state:measurementState(mode:"path",dimensions:true,unit:"1"),german:false)
        let native:UIToolbar=toolbar
        let controls=(native.items ?? []).filter { $0.accessibilityIdentifier?.hasPrefix("form.context.") == true }
        XCTAssertLessThanOrEqual(controls.count,5,"Only essential controls should compete for space in the secondary toolbar")
        XCTAssertTrue(controls.allSatisfy { $0.customView == nil },"System bar items must keep native appearance and layout")
        let mode=try XCTUnwrap(controls.first { $0.accessibilityIdentifier=="form.context.native-measure-mode" })
        let modes=actions(in:try XCTUnwrap(mode.menu))
        XCTAssertEqual(modes.first { $0.title=="Path" }?.state,.on)
        XCTAssertEqual(modes.first { $0.title=="Distance" }?.state,.off)
        let finish=try XCTUnwrap(controls.first { $0.accessibilityIdentifier=="form.context.native-measure-action-finish" })
        XCTAssertFalse(finish.isEnabled,"A path without sufficient points cannot be finished")
        let more=try XCTUnwrap(controls.first { $0.accessibilityIdentifier=="form.context.more" })
        let menu=try XCTUnwrap(more.menu)
        let overflow=actions(in:menu)
        for title in ["Show dimensions","Show selection box","Cancel points","Show measurements","Delete measurement","Millimetres","Inches"] {
            XCTAssertTrue(overflow.contains { $0.title==title },"Moving settings into More must retain: "+title)
        }
        XCTAssertEqual(overflow.first { $0.title=="Show dimensions" }?.state,.on)
        XCTAssertEqual(overflow.first { $0.title=="Millimetres" }?.state,.on)
        let delete=try XCTUnwrap(overflow.first { $0.title=="Delete measurement" })
        XCTAssertTrue(delete.attributes.contains(.destructive))
        XCTAssertTrue(delete.attributes.contains(.disabled),"The destructive command must respect the renderer's current selection")
        XCTAssertNotNil(controls.first { $0.accessibilityIdentifier=="form.context.close" },"Closing tool options stays discoverable outside More")
    }

    func testCompactContextToolbarKeepsPrimaryControlsAndRefreshesNativeMenuState() throws {
        let toolbar=ContextToolbar(frame:CGRect(x:0,y:0,width:320,height:52))
        toolbar.setTool("measure")
        toolbar.update(state:measurementState(mode:"distance",dimensions:false,unit:"1"),german:false)
        toolbar.layoutIfNeeded()
        toolbar.update(state:measurementState(mode:"angle",dimensions:true,unit:"25.4"),german:false)
        toolbar.layoutIfNeeded()
        XCTAssertFalse(toolbar.isHidden)
        XCTAssertEqual(toolbar.tool,"measure")
        let native:UIToolbar=toolbar
        let primaryIDs=Set((native.items ?? []).compactMap(\.accessibilityIdentifier))
        XCTAssertTrue(primaryIDs.isSuperset(of:["form.context.native-measure-mode","form.context.native-measure-action-snap","form.context.native-measure-action-finish","form.context.more","form.context.close"]))
        let mode=try XCTUnwrap(native.items?.first { $0.accessibilityIdentifier=="form.context.native-measure-mode" })
        XCTAssertEqual(actions(in:try XCTUnwrap(mode.menu)).first { $0.title=="Angle" }?.state,.on)
        let more=try XCTUnwrap(native.items?.first { $0.accessibilityIdentifier=="form.context.more" })
        let overflow=actions(in:try XCTUnwrap(more.menu))
        XCTAssertEqual(overflow.first { $0.title=="Show dimensions" }?.state,.on)
        XCTAssertEqual(overflow.first { $0.title=="Inches" }?.state,.on)
        XCTAssertEqual(overflow.first { $0.title=="Millimetres" }?.state,.off)
        toolbar.setTool(nil)
        XCTAssertTrue(toolbar.isHidden)
    }

    private func measurementState(mode:String,dimensions:Bool,unit:String)->[String:Any] {
        let descriptors:[[String:Any]]=[
            ["id":"native-measure-mode","kind":"select","title":"Measurement mode","value":mode,"enabled":true,"options":[["value":"distance","title":"Distance"],["value":"path","title":"Path"],["value":"angle","title":"Angle"]]],
            ["id":"native-measure-action-snap","kind":"toggle","title":"Snap","value":true,"enabled":true],
            ["id":"dimensions","kind":"toggle","title":"Show dimensions","value":dimensions,"enabled":true],
            ["id":"selection-box-toggle","kind":"toggle","title":"Show selection box","value":true,"enabled":true],
            ["id":"unit","kind":"select","title":"Unit","value":unit,"enabled":true,"options":[["value":"1","title":"Millimetres"],["value":"25.4","title":"Inches"]]],
            ["id":"native-measure-action-finish","kind":"button","title":"Finish measurement","enabled":false],
            ["id":"native-measure-action-cancel","kind":"button","title":"Cancel points","enabled":true],
            ["id":"native-measure-action-visibility","kind":"button","title":"Show measurements","enabled":true],
            ["id":"native-measure-action-delete","kind":"button","title":"Delete measurement","enabled":false,"destructive":true]
        ]
        return ["hasModels":true,"panels":["measurement":["sections":[["items":descriptors]]]]]
    }

    private func actions(in menu:UIMenu)->[UIAction] {
        menu.children.flatMap { element -> [UIAction] in
            if let action=element as? UIAction {return [action]}
            if let submenu=element as? UIMenu {return actions(in:submenu)}
            return []
        }
    }

    private func find<T:UIView>(_ type:T.Type,in view:UIView)->T? {
        if let result=view as? T {return result}
        for child in view.subviews {if let result=find(type,in:child) {return result}}
        return nil
    }
}
