import UIKit

/// A system toolbar, with UIKit-owned glass groups and overflow menus. Renderer
/// descriptors remain the only authority for values and action availability.
@MainActor
final class ContextToolbar: UIToolbar {
    var onAction: ((String, Any?) -> Void)?
    var onDismiss: (() -> Void)?
    private(set) var tool: String?
    private(set) var detailAnchor: UIBarButtonItem?
    private var state: [String: Any] = [:]
    private var german = true
    private var lastDescriptor: NSDictionary?
    private let moreItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: nil)

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "form.contextToolbar"
        isTranslucent = true
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 52) }

    func setTool(_ requested: String?) {
        let aliases = ["measurement": "measure", "section": "cut", "display": "view"]
        let next = requested.map { aliases[$0] ?? $0 }
        guard next != tool else { return }
        tool = next; lastDescriptor = nil; isHidden = next == nil
        rebuild()
    }
    func update(state: [String: Any], german: Bool) {
        self.state = state; self.german = german
        rebuild()
    }
    private func title(_ de: String, _ en: String) -> String { german ? de : en }
    private func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        return (value as? NSNumber)?.stringValue ?? ""
    }
    private func isOn(_ item: [String: Any]) -> Bool { item["value"] as? Bool ?? false }

    private func rebuild() {
        guard let tool else { items = []; detailAnchor = nil; return }
        let key = ["measure": "measurement", "cut": "section"][tool] ?? tool
        let panel = (state["panels"] as? [String: [String: Any]])?[key] ?? [:]
        let snapshot: [String: Any] = ["panel": panel, "german": german, "tool": tool]
        guard lastDescriptor?.isEqual(to: snapshot) != true else { return }
        lastDescriptor = snapshot as NSDictionary
        let descriptors = (panel["sections"] as? [[String: Any]] ?? []).flatMap { $0["items"] as? [[String: Any]] ?? [] }
        let byID = Dictionary(descriptors.compactMap { item in (item["id"] as? String).map { ($0, item) } }, uniquingKeysWith: { first, _ in first })
        func button(_ id: String, _ symbol: String) -> UIBarButtonItem? {
            guard let item = byID[id] else { return nil }
            return item["kind"] as? String == "select" ? choice(item, symbol: symbol) : action(item, symbol: symbol)
        }
        func menuItems(_ ids: [String]) -> [UIMenuElement] {
            ids.compactMap { id in byID[id].map { menuElement($0) } }
        }
        func inline(_ children: [UIMenuElement]) -> UIMenu { UIMenu(options: .displayInline, children: children) }
        var tools: [UIBarButtonItem] = [], commands: [UIBarButtonItem] = []
        var additional: [UIMenuElement] = []
        switch tool {
        case "measure":
            tools = [button("native-measure-mode", "ruler"), button("native-measure-action-snap", "scope")].compactMap { $0 }
            if let finish = button("native-measure-action-finish", "checkmark") { commands.append(finish) }
            additional = [
                inline(menuItems(["dimensions", "selection-box-toggle", "unit", "native-measure-action-visibility"])),
                inline(menuItems(["native-measure-action-cancel", "native-measure-action-delete"])),
                detail(tool, title("Alle Messoptionen", "All measurement options"), "slider.horizontal.3")
            ]
        case "cut":
            tools = [button("cut-axis", "square.3.layers.3d"), button("cut-reverse", "arrow.left.arrow.right")].compactMap { $0 }
            additional = [inline(menuItems(["cut"])), detail(tool, title("Schnittposition", "Section position"), "slider.horizontal.3")]
        case "view":
            tools = [button("native-projection", "cube"), button("native-display-mode", "square.stack.3d.up")].compactMap { $0 }
            if let camera = button("screenshot", "camera") { commands.append(camera) }
            additional = [
                inline(menuItems(["grid", "palette", "apple"])),
                detail(tool, title("Ansicht & Hintergrund", "View & background"), "slider.horizontal.3"),
                detail("appearance", title("Farben & Texturen", "Colors & textures"), "paintpalette")
            ]
        case "model":
            tools = [button("translate", "arrow.up.and.down.and.arrow.left.and.right"), button("rotate", "rotate.3d")].compactMap { $0 }
            if let explode = button("explode", "square.stack.3d.up") { commands.append(explode) }
            additional = [
                detail(tool, title("Position & Andocken", "Position & docking"), "move.3d"),
                detail("explode", title("Explosionsansicht", "Exploded view"), "square.stack.3d.up"),
                detail("appearance", title("Farben & Texturen", "Colors & textures"), "paintpalette"),
                inline(menuItems(["undo"]))
            ]
        default: break
        }
        // Keep the popover's origin item stable while renderer values change.
        let more = moreItem; more.menu = UIMenu(children: additional)
        more.accessibilityLabel = title("Weitere Optionen", "More options")
        more.accessibilityIdentifier = "form.context.more"
        detailAnchor = more
        if tool == "measure" { tools.append(more) } else { commands.append(more) }
        let close = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.setTool(nil); self?.onDismiss?()
        })
        close.accessibilityLabel = title("Werkzeugoptionen schließen", "Close tool options")
        close.accessibilityIdentifier = "form.context.close"
        // Fixed spaces split native glass backgrounds; Close is a separate
        // system action. No custom capsule, clipping, scrolling or glass tint.
        setItems([UIBarButtonItem(systemItem: .flexibleSpace)] + tools + [separator()] + commands + [separator(), close, UIBarButtonItem(systemItem: .flexibleSpace)], animated: false)
    }
    private func separator() -> UIBarButtonItem {
        if #available(iOS 26.0, *) { return UIBarButtonItem.fixedSpace() }
        return UIBarButtonItem.fixedSpace(16)
    }
    private func detail(_ tool: String, _ name: String, _ symbol: String) -> UIAction {
        UIAction(title: name, image: UIImage(systemName: symbol), identifier: .init("context-more:" + tool)) { [weak self] _ in self?.onAction?("context-more:" + tool, nil) }
    }
    private func action(_ descriptor: [String: Any], symbol: String) -> UIBarButtonItem {
        let id = string(descriptor["id"]), name = string(descriptor["title"])
        let toggle = descriptor["kind"] as? String == "toggle", selected = isOn(descriptor)
        let callback = UIAction { [weak self] _ in self?.onAction?(id, toggle ? !selected : nil) }
        let item = id == "native-measure-action-finish" ? UIBarButtonItem(systemItem: .done, primaryAction: callback) : UIBarButtonItem(image: UIImage(systemName: symbol), primaryAction: callback)
        item.isEnabled = descriptor["enabled"] as? Bool ?? true
        item.isSelected = selected
        item.accessibilityLabel = name; item.accessibilityIdentifier = "form.context." + id
        if toggle { item.accessibilityValue = selected ? title("Ein", "On") : title("Aus", "Off") }
        return item
    }
    private func choice(_ descriptor: [String: Any], symbol: String) -> UIBarButtonItem {
        let id = string(descriptor["id"]), current = string(descriptor["value"])
        let options = descriptor["options"] as? [[String: Any]] ?? []
        let item = UIBarButtonItem(image: optionSymbol(id: id, value: current) ?? UIImage(systemName: symbol), menu: selectionMenu(descriptor))
        item.isEnabled = descriptor["enabled"] as? Bool ?? true
        item.accessibilityLabel = string(descriptor["title"]); item.accessibilityIdentifier = "form.context." + id
        item.accessibilityValue = options.first { string($0["value"]) == current }.map { string($0["title"]) }
        return item
    }
    private func selectionMenu(_ descriptor: [String: Any]) -> UIMenu {
        let id = string(descriptor["id"]), current = string(descriptor["value"])
        let options = descriptor["options"] as? [[String: Any]] ?? []
        return UIMenu(title: string(descriptor["title"]), options: .singleSelection, children: options.map { option in
            let value = string(option["value"])
            return UIAction(title: string(option["title"]), image: optionSymbol(id: id, value: value), identifier: .init(id + ":" + value), attributes: (descriptor["enabled"] as? Bool == false || option["enabled"] as? Bool == false) ? [.disabled] : [], state: current == value ? .on : .off) { [weak self] _ in self?.onAction?(id, value) }
        })
    }
    private func menuElement(_ descriptor: [String: Any]) -> UIMenuElement {
        if descriptor["kind"] as? String == "select" { return selectionMenu(descriptor) }
        let id = string(descriptor["id"]), toggle = descriptor["kind"] as? String == "toggle", selected = isOn(descriptor)
        var attributes: UIMenuElement.Attributes = descriptor["enabled"] as? Bool == false ? [.disabled] : []
        if id.hasSuffix("delete") || id == "remove" { attributes.insert(.destructive) }
        let symbols = ["dimensions": "arrow.up.left.and.arrow.down.right", "selection-box-toggle": "cube.transparent", "native-measure-action-visibility": "eye", "native-measure-action-cancel": "xmark", "native-measure-action-delete": "trash", "grid": "grid", "palette": "paintpalette", "apple": "leaf", "undo": "arrow.uturn.backward", "cut": "square.split.2x1"]
        return UIAction(title: string(descriptor["title"]), image: symbols[id].flatMap { UIImage(systemName: $0) }, identifier: .init(id), attributes: attributes, state: toggle && selected ? .on : .off) { [weak self] _ in self?.onAction?(id, toggle ? !selected : nil) }
    }
    private func optionSymbol(id: String, value: String) -> UIImage? {
        let symbols: [String: String]
        switch id {
        case "native-measure-mode": symbols = ["distance": "ruler", "path": "point.topleft.down.to.point.bottomright.curvepath", "angle": "angle"]
        case "cut-axis": symbols = ["x": "x.square", "y": "y.square", "z": "z.square"]
        case "native-projection": symbols = ["orthographic": "cube", "perspective": "view.3d"]
        case "native-display-mode": symbols = ["solid": "cube.fill", "edges": "cube", "wireframe": "cube.transparent", "xray": "square.3.layers.3d"]
        default: return nil
        }
        return symbols[value].flatMap { UIImage(systemName: $0) }
    }
}
