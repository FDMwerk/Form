import UIKit

final class FileInformationController: UITableViewController {
    private let groups: [(String, [[String:String]])]
    private let note: String
    init(title: String, rows: [[String:String]], note: String, german: Bool) {
        let dimensions = rows.filter { $0["metric"] == "true" }
        let details = rows.filter { $0["metric"] != "true" }
        groups = [(german ? "Geometrie" : "Geometry", dimensions),(german ? "Datei & Modell" : "File & model",details)].filter { !$0.1.isEmpty }
        self.note = note
        super.init(style:.insetGrouped); self.title = title
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) unavailable") }
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem:.done,primaryAction:UIAction { [weak self] _ in self?.dismiss(animated:true) })
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 60
        tableView.cellLayoutMarginsFollowReadableWidth = true
    }
    override func numberOfSections(in tableView:UITableView)->Int {groups.count}
    override func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int {groups[section].1.count}
    override func tableView(_ tableView:UITableView,titleForHeaderInSection section:Int)->String? {groups[section].0}
    override func tableView(_ tableView:UITableView,titleForFooterInSection section:Int)->String? {section==groups.count-1 ? note : nil}
    override func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let row = groups[indexPath.section].1[indexPath.row]
        let cell=UITableViewCell(style:.subtitle,reuseIdentifier:nil)
        var content=cell.defaultContentConfiguration()
        content.text=row["value"]; content.secondaryText=row["label"]
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.secondaryTextProperties.font = .preferredFont(forTextStyle:.caption1)
        content.textProperties.numberOfLines = 0; content.secondaryTextProperties.numberOfLines = 0
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration=content;cell.selectionStyle = .none
        return cell
    }
}
