import UIKit

/// System UIKit bars inherit the current OS material and accessibility behavior.
/// No sampled blur, custom glass shader or copied background is applied.
@MainActor
final class MobileChrome: NSObject {
    private weak var controller: UIViewController?
    private let navigationBar = UINavigationBar()
    private let toolbar = UIToolbar()
    private let navigationItem = UINavigationItem(title: "Form")
    private var command: ((String) -> Void)?
    private var state: [String: Any] = [:]
    private var lastState: NSDictionary?

    func install(in controller: UIViewController, command: @escaping (String) -> Void) {
        guard self.controller == nil else { return }
        self.controller = controller
        self.command = command
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.isTranslucent = true
        toolbar.isTranslucent = true
        navigationBar.setItems([navigationItem], animated: false)
        controller.view.addSubview(navigationBar)
        controller.view.addSubview(toolbar)
        let safe = controller.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: safe.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            navigationBar.heightAnchor.constraint(equalToConstant: 44),
            toolbar.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            toolbar.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 54)
        ])
        rebuild()
    }

    /// Web-owned labels and availability keep native chrome in sync with the scene.
    /// Expected: title, controls[id] = {label, enabled, active}, unit (string).
    func setState(dictionary: [String: Any]) {
        let snapshot = dictionary as NSDictionary
        guard lastState?.isEqual(to: dictionary) != true else { return }
        lastState = snapshot.copy() as? NSDictionary
        state = dictionary
        rebuild()
    }

    func updateLayout() { rebuild() }

    private func control(_ id: String) -> [String: Any] {
        (state["controls"] as? [String: [String: Any]])?[id] ?? [:]
    }
    private func label(_ id: String, fallback: String) -> String {
        guard let value = control(id)["label"] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return fallback }
        return value
    }
    private func enabled(_ id: String, default fallback: Bool = false) -> Bool {
        if let enabled = control(id)["enabled"] as? Bool { return enabled }
        if let disabled = control(id)["disabled"] as? Bool { return !disabled }
        return fallback
    }
    private func selected(_ id: String) -> Bool {
        (control(id)["active"] as? Bool) == true
    }
    private func send(_ id: String) { command?(id) }

    private func item(_ id: String, symbol: String, fallback: String, defaultEnabled: Bool = false) -> UIBarButtonItem {
        let title = label(id, fallback: fallback)
        let action = UIAction(title: title, image: UIImage(systemName: symbol)) { [weak self] _ in self?.send(id) }
        let button = UIBarButtonItem(title: nil, image: UIImage(systemName: symbol), primaryAction: action, menu: nil)
        button.accessibilityLabel = title
        button.accessibilityIdentifier = "form." + id
        button.isEnabled = enabled(id, default: defaultEnabled)
        if selected(id) { button.tintColor = .systemGreen; button.accessibilityTraits.insert(.selected) }
        return button
    }
    private func action(_ id: String, symbol: String, fallback: String, defaultEnabled: Bool = false) -> UIAction {
        let attributes: UIMenuElement.Attributes = enabled(id, default: defaultEnabled) ? [] : [.disabled]
        return UIAction(title: label(id, fallback: fallback), image: UIImage(systemName: symbol), attributes: attributes, state: selected(id) ? .on : .off) { [weak self] _ in self?.send(id) }
    }
    private func inline(_ children: [UIMenuElement]) -> UIMenu {
        UIMenu(options: .displayInline, children: children)
    }
    private func unitsMenu() -> UIMenu {
        let units = [("0.001", "µm"), ("1", "mm"), ("10", "cm"), ("1000", "m"), ("25.4", "in"), ("304.8", "ft")]
        let selectedUnit = String(describing: state["unit"] ?? "1")
        let children = units.map { value, title in
            UIAction(title: title, attributes: enabled("unit") ? [] : [.disabled], state: selectedUnit == value ? .on : .off) { [weak self] _ in self?.send("unit:" + value) }
        }
        return UIMenu(title: label("unit", fallback: "Units"), image: UIImage(systemName: "ruler"), options: .singleSelection, children: children)
    }
    private func viewMenu() -> UIMenu {
        UIMenu(children: [
            action("display-menu", symbol:"cube", fallback:"Display", defaultEnabled:true),
            action("background-menu", symbol:"sun.max", fallback:"Background", defaultEnabled:true),
            action("grid", symbol:"grid", fallback:"Grid"),
            action("palette", symbol:"paintpalette", fallback:"Component colors"),
            action("apple", symbol:"leaf", fallback:"Reference apple"),
            action("screenshot", symbol:"camera", fallback:"Screenshot")
        ])
    }
    private func measurementMenu() -> UIMenu {
        UIMenu(children:[action("dimensions",symbol:"arrow.up.left.and.arrow.down.right",fallback:"Dimensions"), action("selection-box-toggle",symbol:"cube.transparent",fallback:"Selection box"), action("clear",symbol:"trash",fallback:"Delete measurements"), unitsMenu()])
    }
    private func modelMenu() -> UIMenu {
        UIMenu(children:[action("translate",symbol:"arrow.up.and.down.and.arrow.left.and.right",fallback:"Move"),action("rotate",symbol:"rotate.3d",fallback:"Rotate"),action("explode",symbol:"square.stack.3d.up",fallback:"Explode"),action("undo",symbol:"arrow.uturn.backward",fallback:"Undo"),action("scene-settings",symbol:"slider.horizontal.3",fallback:"Scene settings"),action("model-tools",symbol:"wrench.and.screwdriver",fallback:"Position & docking")])
    }
    private func menuItem(_ id:String, symbol:String, menu:UIMenu) -> UIBarButtonItem {
        let item = UIBarButtonItem(title:nil,image:UIImage(systemName:symbol),primaryAction:nil,menu:menu)
        item.accessibilityLabel = label(id,fallback:id); item.accessibilityIdentifier="form."+id;item.isEnabled=enabled(id,default:true)
        return item
    }
    private func rebuild() {
        navigationItem.title = (state["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Form"
        navigationItem.leftBarButtonItems = [
            item("side", symbol: "sidebar.left", fallback: "Models", defaultEnabled: true),
            item("open", symbol: "folder", fallback: "Open model", defaultEnabled: true)
        ]
        navigationItem.rightBarButtonItems = [
            item("open-with", symbol: "square.and.arrow.up", fallback: "Share"),
            item("info", symbol: "info.circle", fallback: "File information", defaultEnabled: true)
        ]
        let wide = controller?.traitCollection.horizontalSizeClass == .regular && (controller?.view.bounds.width ?? 0) >= 700
        var items = [item("fit",symbol:"viewfinder",fallback:"Fit model"),menuItem("view-tools",symbol:"cube",menu:viewMenu()),UIBarButtonItem(systemItem:.flexibleSpace)]
        items.append(item("measure",symbol:"ruler",fallback:"Measure"))
        items.append(menuItem("measurement-tools",symbol:"slider.horizontal.3",menu:measurementMenu()))
        items.append(item("cut",symbol:"square.split.2x1",fallback:"Section"))
        items.append(UIBarButtonItem(systemItem:.flexibleSpace))
        if wide { items.append(item("translate",symbol:"arrow.up.and.down.and.arrow.left.and.right",fallback:"Move")) }
        items.append(menuItem("model-tools",symbol:"wrench.and.screwdriver",menu:modelMenu()))
        toolbar.setItems(items,animated:false)
    }
}
