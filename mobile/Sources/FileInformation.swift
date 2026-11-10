import UIKit

/// Compact native metrics and file details; values always come from the renderer.
final class FileInformationController: UITableViewController {
    private let groups: [(String, [[String:String]])]
    private let note: String
    private let hasMetrics: Bool
    private var lastMetricColumns = 0

    init(title: String, rows: [[String:String]], note: String, german: Bool) {
        let isMetric: ([String:String]) -> Bool = { row in
            row["metric"] == "true" || Self.metricKind(row) != nil
        }
        let metrics = rows.filter(isMetric).enumerated().sorted { lhs, rhs in
            let order = ["width":0,"depth":1,"height":2,"volume":3]
            let a = order[Self.metricKind(lhs.element) ?? ""] ?? 2
            let b = order[Self.metricKind(rhs.element) ?? ""] ?? 2
            return a == b ? lhs.offset < rhs.offset : a < b
        }.map(\.element)
        let details = rows.filter { !isMetric($0) }
        groups = [(german ? "Geometrie" : "Geometry", metrics),
                  (german ? "Datei & Modell" : "File & model",details)].filter { !$0.1.isEmpty }
        hasMetrics = !metrics.isEmpty
        self.note = note
        super.init(style:.insetGrouped)
        self.title = title
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem:.done,primaryAction:UIAction { [weak self] _ in self?.dismiss(animated:true) })
        tableView.accessibilityIdentifier = "form.fileInformation"
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.cellLayoutMarginsFollowReadableWidth = true
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let columns = metricColumns
        guard lastMetricColumns != columns else {return}
        lastMetricColumns = columns
        tableView.reloadData()
    }
    private var metricColumns: Int {
        traitCollection.preferredContentSizeCategory.isAccessibilityCategory || tableView.bounds.width < 280 ? 1 : 2
    }
    private static func metricKind(_ row:[String:String]) -> String? {
        if let kind = row["kind"] ?? row["key"], ["width","depth","height","volume"].contains(kind) {return kind}
        switch (row["label"] ?? "").lowercased() {
        case "breite","width": return "width"
        case "tiefe","depth": return "depth"
        case "höhe","height": return "height"
        case "volumen","volume": return "volume"
        default: return (row["value"] ?? "").hasSuffix(" cm³") ? "volume" : nil
        }
    }
    override func numberOfSections(in tableView:UITableView)->Int {groups.count}
    override func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int {
        hasMetrics && section == 0 ? 1 : groups[section].1.count
    }
    override func tableView(_ tableView:UITableView,titleForHeaderInSection section:Int)->String? {groups[section].0}
    override func tableView(_ tableView:UITableView,titleForFooterInSection section:Int)->String? {section==groups.count-1 ? note : nil}
    override func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        if hasMetrics && indexPath.section == 0 {
            let cell = MetricTilesCell(metrics:groups[0].1,columns:metricColumns)
            cell.accessibilityIdentifier = "form.fileInformation.metrics"
            return cell
        }
        let row = groups[indexPath.section].1[indexPath.row]
        let accessible = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let cell = UITableViewCell(style:accessible ? .subtitle : .value1,reuseIdentifier:nil)
        var content = cell.defaultContentConfiguration()
        content.text = row["label"]
        content.secondaryText = row["value"]
        content.textProperties.font = .preferredFont(forTextStyle:.subheadline)
        content.textProperties.color = .secondaryLabel
        content.secondaryTextProperties.font = .preferredFont(forTextStyle:.subheadline)
        content.secondaryTextProperties.color = .label
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }

    private final class MetricTilesCell: UITableViewCell {
        init(metrics:[[String:String]], columns:Int) {
            super.init(style:.default,reuseIdentifier:nil)
            selectionStyle = .none
            backgroundConfiguration = .clear()
            separatorInset = UIEdgeInsets(top:0,left:10_000,bottom:0,right:0)
            let grid = UIStackView()
            grid.axis = .vertical;grid.spacing = 10
            grid.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(grid)
            NSLayoutConstraint.activate([
                grid.leadingAnchor.constraint(equalTo:contentView.leadingAnchor),
                grid.trailingAnchor.constraint(equalTo:contentView.trailingAnchor),
                grid.topAnchor.constraint(equalTo:contentView.topAnchor),
                grid.bottomAnchor.constraint(equalTo:contentView.bottomAnchor)
            ])
            for start in stride(from:0,to:metrics.count,by:columns) {
                let line = UIStackView();line.axis = .horizontal
                line.spacing = 10;line.distribution = .fillEqually;line.alignment = .fill
                for offset in 0..<columns {
                    let index = start+offset
                    line.addArrangedSubview(index < metrics.count ? Self.tile(metrics[index]) : UIView())
                }
                grid.addArrangedSubview(line)
            }
        }
        required init?(coder:NSCoder) { fatalError("init(coder:) unavailable") }
        private static func tile(_ metric:[String:String]) -> UIView {
            let kind = FileInformationController.metricKind(metric)
            let symbols = ["width":"arrow.left.and.right","depth":"arrow.up.left.and.arrow.down.right","height":"arrow.up.and.down","volume":"cube"]
            let surface = UIView()
            surface.backgroundColor = .secondarySystemGroupedBackground
            surface.layer.cornerRadius = 14;surface.layer.cornerCurve = .continuous
            surface.isAccessibilityElement = true
            surface.accessibilityLabel = metric["label"]
            surface.accessibilityValue = metric["value"]
            if let kind {surface.accessibilityIdentifier = "form.fileInformation.metric."+kind}
            let icon = UIImageView(image:UIImage(systemName:symbols[kind ?? ""] ?? "ruler"))
            icon.tintColor = .secondaryLabel;icon.contentMode = .scaleAspectFit
            icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle:.caption1)
            icon.setContentHuggingPriority(.required,for:.horizontal)
            icon.isAccessibilityElement = false
            let caption = UILabel()
            caption.text = metric["label"];caption.font = .preferredFont(forTextStyle:.caption1)
            caption.adjustsFontForContentSizeCategory = true;caption.textColor = .secondaryLabel
            caption.numberOfLines = 0;caption.isAccessibilityElement = false
            let heading = UIStackView(arrangedSubviews:[icon,caption])
            heading.axis = .horizontal;heading.spacing = 6;heading.alignment = .firstBaseline
            let value = UILabel()
            value.text = metric["value"]
            value.font = .preferredFont(forTextStyle:.headline)
            value.adjustsFontForContentSizeCategory = true
            value.numberOfLines = 0;value.isAccessibilityElement = false
            let content = UIStackView(arrangedSubviews:[heading,value])
            content.axis = .vertical;content.spacing = 8
            content.translatesAutoresizingMaskIntoConstraints = false
            surface.addSubview(content)
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo:surface.leadingAnchor,constant:12),
                content.trailingAnchor.constraint(equalTo:surface.trailingAnchor,constant:-12),
                content.topAnchor.constraint(equalTo:surface.topAnchor,constant:12),
                content.bottomAnchor.constraint(equalTo:surface.bottomAnchor,constant:-12)
            ])
            return surface
        }
    }
}
