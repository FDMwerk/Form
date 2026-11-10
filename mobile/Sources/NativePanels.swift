import UIKit

/// Native inspector forms. Descriptors come from the live renderer; controls do not
/// duplicate geometry state or apply unconfirmed machine/printer settings.
@MainActor
final class NativePanelController: UITableViewController, UIColorPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    private var sections: [[String: Any]]
    private var pendingSections: [[String: Any]]?
    private let onAction: (String, Any?) -> Void
    private var activeEditors = Set<String>()
    private var colorID: String?
    private var lastSnapshot: NSArray?

    init(title: String, sections: [[String: Any]], onAction: @escaping (String, Any?) -> Void) {
        self.sections = sections
        self.onAction = onAction
        super.init(style: .insetGrouped)
        self.title = title
        lastSnapshot = sections as NSArray
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 54
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.keyboardDismissMode = .interactive
        tableView.accessibilityIdentifier = "native.panel"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    /// Updating the model during a slider drag must not replace the active control.
    /// The latest state is applied when the drag or native editor finishes.
    func update(sections next: [[String: Any]]) {
        guard !activeEditors.isEmpty else { apply(next); return }
        pendingSections = next
    }

    private func apply(_ next: [[String: Any]]) {
        guard lastSnapshot?.isEqual(to: next) != true else { return }
        sections = next
        lastSnapshot = next as NSArray
        if isViewLoaded { tableView.reloadData() }
    }

    private func beginEditing(_ id: String) { activeEditors.insert(id) }
    private func endEditing(_ id: String) {
        activeEditors.remove(id)
        if activeEditors.isEmpty, let next = pendingSections {
            pendingSections = nil
            apply(next)
        }
    }

    private func items(_ section: Int) -> [[String: Any]] {
        sections[section]["items"] as? [[String: Any]] ?? []
    }
    private func enabled(_ item: [String: Any]) -> Bool { item["enabled"] as? Bool ?? true }
    private func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }
    private func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        return Double(string(value))
    }
    private func formatted(_ value: Double, item: [String: Any]) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? String(value)) + ((item["unit"] as? String).map { " " + $0 } ?? "")
    }
    private func bounded(_ value: Double, item: [String: Any]) -> Double {
        var result = value
        if let minimum = number(item["min"]) { result = max(minimum, result) }
        if let maximum = number(item["max"]) { result = min(maximum, result) }
        let step = number(item["step"]) ?? 0
        if step > 0 {
            let base = number(item["min"]) ?? 0
            result = base + ((result - base) / step).rounded() * step
            if let maximum = number(item["max"]) { result = min(maximum, result) }
        }
        return result
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items(section).count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section]["title"] as? String }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { sections[section]["footer"] as? String }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { UITableView.automaticDimension }

    override func tableView(_ tableView: UITableView, cellForRowAt path: IndexPath) -> UITableViewCell {
        let item = items(path.section)[path.row]
        let id = string(item["id"]), title = string(item["title"]), kind = string(item["kind"])
        if kind == "range" { return rangeCell(item) }
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.accessibilityIdentifier = "native.panel." + id
        var content = cell.defaultContentConfiguration()
        content.text = title
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.directionalLayoutMargins.top = 13
        content.directionalLayoutMargins.bottom = 13
        cell.selectionStyle = .none
        if !enabled(item) { content.textProperties.color = .tertiaryLabel }
        switch kind {
        case "toggle":
            let control = UISwitch()
            control.isOn = item["value"] as? Bool ?? (number(item["value"]) == 1)
            control.isEnabled = enabled(item)
            control.accessibilityLabel = title
            control.accessibilityIdentifier = "native.panel." + id
            control.addAction(UIAction { [weak self] action in
                guard let control = action.sender as? UISwitch else { return }
                self?.onAction(id, control.isOn)
            }, for: .valueChanged)
            cell.accessoryView = control
        case "select":
            let options = item["options"] as? [[String: Any]] ?? []
            let current = string(item["value"])
            let currentTitle = options.first { string($0["value"]) == current }.map { string($0["title"]) } ?? current
            let button = UIButton(type: .system)
            button.setTitle(currentTitle, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .body)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.contentHorizontalAlignment = .trailing
            button.accessibilityLabel = title
            button.accessibilityValue = currentTitle
            button.accessibilityIdentifier = "native.panel." + id
            button.isEnabled = enabled(item)
            button.showsMenuAsPrimaryAction = true
            button.menu = UIMenu(title: title, options: .singleSelection, children: options.map { option in
                let value = string(option["value"])
                return UIAction(title: string(option["title"]), attributes: (option["enabled"] as? Bool) == false ? [.disabled] : [], state: value == current ? .on : .off) { [weak self] _ in
                    self?.onAction(id, value)
                }
            })
            button.frame = CGRect(x: 0, y: 0, width: min(max(110, tableView.bounds.width * 0.42), 250), height: 44)
            cell.accessoryView = button
        case "number":
            content.secondaryText = number(item["value"]).map { formatted($0, item: item) } ?? string(item["value"])
            cell.accessoryType = enabled(item) ? .disclosureIndicator : .none
            cell.selectionStyle = enabled(item) ? .default : .none
            if enabled(item) { cell.accessibilityTraits.insert(.button) }
        case "color":
            let swatch = UIButton(type: .system)
            let value = string(item["value"])
            swatch.backgroundColor = Self.color(value)
            swatch.layer.cornerRadius = 12
            swatch.layer.borderWidth = 1
            swatch.layer.borderColor = UIColor.separator.cgColor
            swatch.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
            swatch.accessibilityLabel = title
            swatch.accessibilityValue = value
            swatch.accessibilityIdentifier = "native.panel." + id
            swatch.isEnabled = enabled(item)
            swatch.addAction(UIAction { [weak self] _ in self?.pickColor(item) }, for: .touchUpInside)
            cell.accessoryView = swatch
        case "button":
            content.textProperties.color = enabled(item) ? ((item["destructive"] as? Bool) == true ? .systemRed : .tintColor) : .tertiaryLabel
            if let symbol = item["symbol"] as? String { content.image = UIImage(systemName: symbol) }
            cell.selectionStyle = enabled(item) ? .default : .none
            cell.accessibilityTraits.insert(.button)
        default:
            content.secondaryText = string(item["value"])
            content.textProperties.color = .secondaryLabel
            content.textProperties.font = .preferredFont(forTextStyle: .footnote)
        }
        cell.contentConfiguration = content
        return cell
    }

    private func rangeCell(_ item: [String: Any]) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let id = string(item["id"]), title = string(item["title"])
        cell.selectionStyle = .none
        cell.accessibilityIdentifier = "native.panel." + id
        let label = UILabel(), value = UILabel(), slider = NativePanelSlider()
        label.text = title; label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true; label.numberOfLines = 0
        value.font = .preferredFont(forTextStyle: .caption1); value.adjustsFontForContentSizeCategory = true
        value.textColor = .secondaryLabel
        value.setContentHuggingPriority(.required, for: .horizontal)
        slider.minimumValue = Float(number(item["min"]) ?? 0)
        slider.maximumValue = Float(max(Double(slider.minimumValue) + 0.0001, number(item["max"]) ?? 1))
        slider.value = Float(number(item["value"]) ?? 0)
        slider.stepValue = Float(number(item["step"]) ?? Double(slider.maximumValue - slider.minimumValue) / 100)
        slider.isEnabled = enabled(item)
        slider.accessibilityLabel = title; slider.accessibilityIdentifier = "native.panel." + id
        value.text = formatted(Double(slider.value), item: item)
        slider.accessibilityValue = value.text
        let heading = UIStackView(arrangedSubviews: [label, value]); heading.spacing = 12; heading.alignment = .firstBaseline
        let stack = UIStackView(arrangedSubviews: [heading, slider]); stack.axis = .vertical; stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false; cell.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            slider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        slider.addAction(UIAction { [weak self] _ in self?.beginEditing(id) }, for: .touchDown)
        slider.addAction(UIAction { [weak self, weak value] action in
            guard let self, let slider = action.sender as? UISlider else { return }
            let result = self.bounded(Double(slider.value), item: item)
            slider.value = Float(result)
            let text = self.formatted(result, item: item)
            value?.text = text; slider.accessibilityValue = text
            self.onAction(id, result)
        }, for: .valueChanged)
        slider.addAction(UIAction { [weak self] _ in self?.endEditing(id) }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt path: IndexPath) {
        tableView.deselectRow(at: path, animated: true)
        let item = items(path.section)[path.row]
        guard enabled(item) else { return }
        switch string(item["kind"]) {
        case "button": onAction(string(item["id"]), nil)
        case "number": editNumber(item)
        case "color": pickColor(item)
        default: break
        }
    }

    private func editNumber(_ item: [String: Any]) {
        guard presentedViewController == nil else { return }
        let id = string(item["id"])
        beginEditing(id)
        let alert = UIAlertController(title: string(item["title"]), message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .numbersAndPunctuation
            field.text = self.string(item["value"])
            field.accessibilityIdentifier = "native.panel.input." + id
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel numeric edit"), style: .cancel) { [weak self] _ in self?.endEditing(id) })
        let confirm = UIAlertAction(title: "OK", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let text = alert?.textFields?.first?.text ?? ""
            let parsed = Self.parseNumber(text)
            if let parsed, parsed.isFinite { self.onAction(id, self.bounded(parsed, item: item)) }
            self.endEditing(id)
        }
        alert.addAction(confirm)
        confirm.isEnabled = Self.parseNumber(alert.textFields?.first?.text ?? "") != nil
        alert.textFields?.first?.addAction(UIAction { [weak alert, weak confirm] _ in
            confirm?.isEnabled = Self.parseNumber(alert?.textFields?.first?.text ?? "") != nil
        }, for: .editingChanged)
        present(alert, animated: true)
    }

    private func pickColor(_ item: [String: Any]) {
        guard presentedViewController == nil else { return }
        let id = string(item["id"])
        colorID = id; beginEditing(id)
        let picker = UIColorPickerViewController()
        picker.title = string(item["title"])
        picker.selectedColor = Self.color(string(item["value"])) ?? .systemGray
        picker.supportsAlpha = false; picker.delegate = self
        present(picker, animated: true)
        picker.presentationController?.delegate = self
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if let id = colorID { endEditing(id) }; colorID = nil
    }
    private static func parseNumber(_ text: String) -> Double? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Both common decimal separators are accepted; do not interpret a model
        // value such as "3.2" as a grouped integer on a German system.
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        guard let id = colorID, let hex = Self.hex(viewController.selectedColor) else { return }
        onAction(id, hex)
    }
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        if let id = colorID { endEditing(id) }; colorID = nil
    }
    private static func color(_ hex: String) -> UIColor? {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        return UIColor(red: CGFloat((number >> 16) & 255) / 255, green: CGFloat((number >> 8) & 255) / 255, blue: CGFloat(number & 255) / 255, alpha: 1)
    }
    private static func hex(_ color: UIColor) -> String? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return String(format: "#%02x%02x%02x", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}

private final class NativePanelSlider: UISlider {
    var stepValue: Float = 0.01
    override func accessibilityIncrement() { value = min(maximumValue, value + max(stepValue, 0.0001)); sendActions(for: .valueChanged) }
    override func accessibilityDecrement() { value = max(minimumValue, value - max(stepValue, 0.0001)); sendActions(for: .valueChanged) }
}
