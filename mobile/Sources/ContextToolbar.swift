import UIKit

/// iPad tool options stay next to the scene rather than covering it with a sheet.
/// Every value and availability flag comes from the same renderer descriptors as
/// the full native inspector. The toolbar owns presentation, never CAD state.
@MainActor
final class ContextToolbar: UIView {
    var onAction: ((String, Any?) -> Void)?
    var onDismiss: (() -> Void)?
    private(set) var tool: String?
    private let scroll = UIScrollView()
    private let bar = UIToolbar()
    private var barWidth: NSLayoutConstraint!
    private var state: [String: Any] = [:]
    private var german = true
    private var editing = false
    private var lastDescriptor: NSDictionary?

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "form.contextToolbar"
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.translatesAutoresizingMaskIntoConstraints = false
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.isTranslucent = true
        bar.layer.cornerRadius=26;bar.layer.cornerCurve = .continuous;bar.clipsToBounds=true
        addSubview(scroll); scroll.addSubview(bar)
        barWidth = bar.widthAnchor.constraint(equalToConstant: 320)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            bar.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            bar.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            bar.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            barWidth
        ])
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 52) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let padding = max(0, (scroll.bounds.width - barWidth.constant) / 2)
        guard abs(scroll.contentInset.left - padding) > 0.5 else { return }
        scroll.contentInset = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
        // A short tool group stays centered above the primary toolbar. In a
        // narrow window the padding becomes zero and all options still scroll.
        scroll.setContentOffset(CGPoint(x: -padding, y: 0), animated: false)
    }

    func setTool(_ requested: String?) {
        let aliases = ["measurement": "measure", "section": "cut", "display": "view"]
        let next = requested.map { aliases[$0] ?? $0 }
        guard next != tool else { return }
        tool = next; lastDescriptor = nil; editing = false
        isHidden = next == nil
        scroll.setContentOffset(CGPoint(x: -scroll.contentInset.left, y: 0), animated: false)
        rebuild()
    }

    func update(state: [String: Any], german: Bool) {
        self.state = state; self.german = german
        // A renderer response must not replace the slider underneath a finger.
        if !editing { rebuild() }
    }

    private func title(_ de: String, _ en: String) -> String { german ? de : en }
    private func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        return (value as? NSNumber)?.stringValue ?? ""
    }
    private func number(_ value: Any?, _ fallback: Double) -> Double {
        if let value = value as? NSNumber { return value.doubleValue }
        return Double(string(value)) ?? fallback
    }
    private func isOn(_ item: [String: Any]) -> Bool { item["value"] as? Bool ?? false }

    private func rebuild() {
        guard let tool else { bar.items = []; return }
        let key = ["measure": "measurement", "cut": "section"][tool] ?? tool
        let panel = (state["panels"] as? [String: [String: Any]])?[key] ?? [:]
        let snapshot: [String: Any] = ["panel": panel, "german": german, "tool": tool, "hasModels": state["hasModels"] ?? false]
        guard lastDescriptor?.isEqual(to: snapshot) != true else { return }
        lastDescriptor = snapshot as NSDictionary
        let descriptors = (panel["sections"] as? [[String: Any]] ?? []).flatMap { $0["items"] as? [[String: Any]] ?? [] }
        let itemsByID = Dictionary(descriptors.compactMap { item in
            (item["id"] as? String).map { ($0, item) }
        }, uniquingKeysWith: { first, _ in first })
        var items: [UIBarButtonItem] = []
        func add(_ id: String, _ symbol: String, width: CGFloat = 44) {
            guard let descriptor = itemsByID[id] else { return }
            let item: UIBarButtonItem
            switch descriptor["kind"] as? String {
            case "range": item = slider(descriptor)
            case "select": item = choice(descriptor, symbol: symbol)
            default: item = action(descriptor, symbol: symbol)
            }
            if item.customView == nil { item.width = width }
            items.append(item)
        }
        switch tool {
        case "measure":
            add("native-measure-mode", "ruler")
            add("native-measure-action-snap", "scope")
            add("dimensions", "arrow.up.left.and.arrow.down.right")
            add("selection-box-toggle", "cube.transparent")
            add("unit", "number")
            add("native-measure-action-finish", "checkmark")
            add("native-measure-action-cancel", "xmark")
            add("native-measure-action-visibility", "eye")
            add("native-measure-action-delete", "trash")
        case "cut":
            add("cut", "square.split.2x1")
            add("cut-axis", "square.3.layers.3d")
            add("cut-value", "slider.horizontal.3")
            add("cut-reverse", "arrow.left.arrow.right")
        case "view":
            add("native-projection", "cube")
            add("native-display-mode", "square.stack.3d.up")
            add("grid", "grid")
            add("palette", "paintpalette")
            add("apple", "leaf")
            add("screenshot", "camera")
        case "model":
            add("translate", "arrow.up.and.down.and.arrow.left.and.right")
            add("rotate", "rotate.3d")
            add("explode", "square.stack.3d.up")
            add("explode-value", "slider.horizontal.3")
            add("undo", "arrow.uturn.backward")
        default: break
        }
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), primaryAction: UIAction { [weak self] _ in
            self?.onAction?("context-more:" + tool, nil)
        })
        more.width = 44; more.accessibilityLabel = title("Weitere Optionen", "More options")
        more.accessibilityIdentifier = "form.context.more"
        if ["view","model"].contains(tool) {
            more.primaryAction=nil
            more.menu=UIMenu(children:[
                UIAction(title:title(tool=="view" ? "Ansicht & Hintergrund":"Position & Andocken",tool=="view" ? "View & background":"Position & docking"),image:UIImage(systemName:"slider.horizontal.3")) { [weak self] _ in self?.onAction?("context-more:"+tool,nil) },
                UIAction(title:title("Farben & Texturen","Colors & textures"),image:UIImage(systemName:"paintpalette")) { [weak self] _ in self?.onAction?("context-more:appearance",nil) }
            ])
        }
        let close = UIBarButtonItem(image: UIImage(systemName: "xmark"), primaryAction: UIAction { [weak self] _ in
            self?.setTool(nil); self?.onDismiss?()
        })
        close.width = 44; close.accessibilityLabel = title("Werkzeugoptionen schließen", "Close tool options")
        close.accessibilityIdentifier = "form.context.close"
        items.append(contentsOf: [more, close])
        bar.setItems(items, animated: false)
        // A small Split View window can scroll the options, instead of shrinking
        // controls below Apple's touch target or dropping hidden actions.
        // UIKit's floating toolbar groups need outer and inter-item spacing in
        // addition to the 44-point targets, including the first/last menu item.
        barWidth.constant = items.reduce(CGFloat(112)) { $0 + ($1.customView?.bounds.width ?? max(44, $1.width)) }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func action(_ descriptor: [String: Any], symbol: String) -> UIBarButtonItem {
        let id = string(descriptor["id"]), name = string(descriptor["title"])
        let toggle = descriptor["kind"] as? String == "toggle"
        let selected = isOn(descriptor)
        let item = UIBarButtonItem(image: UIImage(systemName: symbol), primaryAction: UIAction(title: name) { [weak self] _ in
            self?.onAction?(id, toggle ? !selected : nil)
        })
        item.isEnabled = descriptor["enabled"] as? Bool ?? true
        item.accessibilityLabel = name; item.accessibilityIdentifier = "form.context." + id
        if toggle {
            item.accessibilityValue = selected ? title("Ein", "On") : title("Aus", "Off")
            if selected { item.tintColor = .systemGreen; item.accessibilityTraits.insert(.selected) }
        }
        return item
    }

    private func choice(_ descriptor: [String: Any], symbol: String) -> UIBarButtonItem {
        let id = string(descriptor["id"]), current = string(descriptor["value"])
        let options = descriptor["options"] as? [[String: Any]] ?? []
        let name = string(descriptor["title"])
        let menu = UIMenu(title: name, options: .singleSelection, children: options.map { option in
            let value = string(option["value"])
            return UIAction(title: string(option["title"]), image: optionSymbol(id: id, value: value), attributes: option["enabled"] as? Bool == false ? [.disabled] : [], state: current == value ? .on : .off) { [weak self] _ in
                self?.onAction?(id, value)
            }
        })
        let item = UIBarButtonItem(image: optionSymbol(id: id, value: current) ?? UIImage(systemName: symbol), menu: menu)
        item.isEnabled = descriptor["enabled"] as? Bool ?? true
        item.accessibilityLabel = name; item.accessibilityIdentifier = "form.context." + id
        item.accessibilityValue = options.first { string($0["value"]) == current }.map { string($0["title"]) }
        return item
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

    private func slider(_ descriptor: [String: Any]) -> UIBarButtonItem {
        let id = string(descriptor["id"]), name = string(descriptor["title"])
        let control = UISlider(frame: CGRect(x: 0, y: 0, width: 160, height: 44))
        let minimum = number(descriptor["min"], 0), maximum = max(minimum + 0.0001, number(descriptor["max"], 100))
        let step = number(descriptor["step"], 1)
        control.minimumValue = Float(minimum); control.maximumValue = Float(maximum)
        control.value = Float(number(descriptor["value"], minimum))
        control.isEnabled = descriptor["enabled"] as? Bool ?? true
        control.accessibilityLabel = name; control.accessibilityIdentifier = "form.context." + id
        control.addAction(UIAction { [weak self] _ in self?.editing = true }, for: .touchDown)
        control.addAction(UIAction { [weak self] action in
            guard let self, let slider = action.sender as? UISlider else { return }
            var value = Double(slider.value)
            if step > 0 { value = minimum + ((value - minimum) / step).rounded() * step }
            value = min(maximum, max(minimum, value)); slider.value = Float(value)
            slider.accessibilityValue = value.formatted(.number.precision(.fractionLength(0...2)))
            self.onAction?(id, value)
        }, for: .valueChanged)
        control.addAction(UIAction { [weak self] _ in
            guard let self else { return }; self.editing = false; self.lastDescriptor = nil; self.rebuild()
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return UIBarButtonItem(customView: control)
    }
}
