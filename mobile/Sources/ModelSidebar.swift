import UIKit

/// A system sidebar list: native selection, disclosure, swipe and context menus.
final class ModelSidebarController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    let collectionView = UICollectionView(frame:.zero,collectionViewLayout:UICollectionViewCompositionalLayout.list(using:UICollectionLayoutListConfiguration(appearance:.sidebar)))
    let footerCollectionView = UICollectionView(frame:.zero,collectionViewLayout:UICollectionViewCompositionalLayout.list(using:UICollectionLayoutListConfiguration(appearance:.sidebar)))
    private var footerHeight: NSLayoutConstraint!
    private var pinsFooter = false
    var command: ((String,String,Bool)->Void)?
    private var rows: [[String:Any]] = []
    private var controls: [String:[String:Any]] = [:]
    private var german = true
    private var multi = false
    private var lastSnapshot: NSDictionary?
    init() { super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) unavailable") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        for list in [collectionView,footerCollectionView] {
            list.translatesAutoresizingMaskIntoConstraints=false
            list.backgroundColor = .clear
            list.dataSource=self;list.delegate=self
            list.register(UICollectionViewListCell.self,forCellWithReuseIdentifier:"row")
            view.addSubview(list)
        }
        collectionView.accessibilityIdentifier="form.modelSidebar"
        footerCollectionView.accessibilityIdentifier="form.sidebarFooter"
        footerCollectionView.contentInsetAdjustmentBehavior = .never
        footerCollectionView.alwaysBounceVertical=false
        footerHeight=footerCollectionView.heightAnchor.constraint(equalToConstant:0)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo:view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo:footerCollectionView.topAnchor),
            footerCollectionView.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            footerCollectionView.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            footerCollectionView.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor),
            footerHeight
        ])
        collectionView.allowsMultipleSelection=true
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        rebuildLayout()
        updateFooterPlacement()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard pinsFooter else {return}
        footerCollectionView.layoutIfNeeded()
        // Let native list cells size for the current text size. In short windows,
        // the footer scrolls independently and leaves space for the model tree.
        let desired=footerCollectionView.collectionViewLayout.collectionViewContentSize.height
        let available=view.safeAreaLayoutGuide.layoutFrame.height
        let height=min(max(132,desired),max(44,available*0.45))
        if abs(footerHeight.constant-height)>0.5 {
            footerHeight.constant=height
            view.setNeedsLayout()
        }
        footerCollectionView.isScrollEnabled=desired>height+0.5
    }
    override func traitCollectionDidChange(_ previousTraitCollection:UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard isViewLoaded else {return}
        updateFooterPlacement()
        collectionView.collectionViewLayout.invalidateLayout()
        footerCollectionView.collectionViewLayout.invalidateLayout()
        view.setNeedsLayout()
    }
    private func updateFooterPlacement() {
        let shouldPin=traitCollection.userInterfaceIdiom == .pad
        guard shouldPin != pinsFooter || footerCollectionView.isHidden == shouldPin else {return}
        pinsFooter=shouldPin
        footerCollectionView.isHidden = !shouldPin
        footerHeight.constant=shouldPin ? 160 : 0
        collectionView.reloadData();footerCollectionView.reloadData()
        view.setNeedsLayout()
    }
    private func rebuildLayout() {
        var config=UICollectionLayoutListConfiguration(appearance:.sidebar)
        config.backgroundColor = .clear
        config.headerMode = .supplementary
        config.trailingSwipeActionsConfigurationProvider = { [weak self] path in self?.swipes(path) }
        collectionView.setCollectionViewLayout(UICollectionViewCompositionalLayout.list(using:config),animated:false)
        collectionView.register(UICollectionViewListCell.self,forSupplementaryViewOfKind:UICollectionView.elementKindSectionHeader,withReuseIdentifier:"header")
        var footerConfig=UICollectionLayoutListConfiguration(appearance:.sidebar);footerConfig.backgroundColor = .clear
        footerCollectionView.setCollectionViewLayout(UICollectionViewCompositionalLayout.list(using:footerConfig),animated:false)
    }
    func setState(_ state:[String:Any],controls:[String:[String:Any]],german:Bool) {
        let snapshot: [String:Any] = ["state":state,"controls":controls,"german":german]
        if lastSnapshot?.isEqual(to:snapshot) == true {return}
        lastSnapshot=snapshot as NSDictionary
        self.rows=state["rows"] as? [[String:Any]] ?? [];self.controls=controls;self.german=german
        title=german ? "Modelle" : "Models"
        navigationItem.rightBarButtonItem=UIBarButtonItem(image:UIImage(systemName:multi ? "checkmark.circle.fill":"checkmark.circle"),primaryAction:UIAction { [weak self] _ in
            guard let self else {return};self.multi.toggle();self.lastSnapshot=nil;self.setState(["rows":self.rows],controls:self.controls,german:self.german)
        })
        navigationItem.rightBarButtonItem?.accessibilityLabel=german ? "Mehrfachauswahl":"Select multiple"
        if isViewLoaded {
            collectionView.reloadData();footerCollectionView.reloadData()
            view.setNeedsLayout()
            for (index,row) in rows.enumerated() where row["selected"] as? Bool == true {collectionView.selectItem(at:IndexPath(item:index,section:1),animated:false,scrollPosition:[])}
        }
    }
    private let actions=["open","openExample","settings","feedback","legal"]
    func numberOfSections(in collectionView:UICollectionView)->Int {collectionView === footerCollectionView ? 1 : pinsFooter ? 2 : 3}
    func collectionView(_ collectionView:UICollectionView,numberOfItemsInSection section:Int)->Int {collectionView === footerCollectionView ? 3 : section==0 ? 2 : section==1 ? rows.count : 3}
    func collectionView(_ collectionView:UICollectionView,viewForSupplementaryElementOfKind kind:String,at indexPath:IndexPath)->UICollectionReusableView {
        let cell=collectionView.dequeueReusableSupplementaryView(ofKind:kind,withReuseIdentifier:"header",for:indexPath) as! UICollectionViewListCell
        var content=cell.defaultContentConfiguration();content.text=indexPath.section==1 ? (german ? "In dieser Szene":"In this scene") : nil
        cell.contentConfiguration=content;return cell
    }
    func collectionView(_ collectionView:UICollectionView,cellForItemAt path:IndexPath)->UICollectionViewCell {
        let cell=collectionView.dequeueReusableCell(withReuseIdentifier:"row",for:path) as! UICollectionViewListCell
        var content=UIListContentConfiguration.sidebarCell();cell.accessories=[]
        if collectionView === self.collectionView && path.section==1 {
            let row=rows[path.item];let kind=row["kind"] as? String ?? "model"
            content.text=row["name"] as? String;content.secondaryText=row["badge"] as? String
            content.image=UIImage(systemName:kind=="all" ? "square.stack.3d.up" : kind=="measurement" ? "ruler" : "cube")
            content.directionalLayoutMargins.leading += CGFloat(min(row["depth"] as? Int ?? 0,5))*14
            if row["visible"] as? Bool == false {content.image=UIImage(systemName:"eye.slash");content.textProperties.color = .secondaryLabel}
            if row["selected"] as? Bool == true {cell.accessories.append(.checkmark())}
            if row["expandable"] as? Bool == true {
                let button=UIButton(type:.system);button.setImage(UIImage(systemName:row["expanded"] as? Bool == true ? "chevron.down":"chevron.forward"),for:.normal)
                button.frame=CGRect(x:0,y:0,width:44,height:44);button.accessibilityLabel=german ? "Unterkomponenten":"Components"
                let id=row["id"] as? String ?? ""
                button.addAction(UIAction { [weak self] _ in self?.command?("expand",id,false) },for:.touchUpInside)
                cell.accessories.append(.customView(configuration:.init(customView:button,placement:.trailing())))
            }
            cell.accessibilityIdentifier="form.sidebar."+(row["id"] as? String ?? "")
        } else {
            let id=actions[collectionView === footerCollectionView || path.section==2 ? path.item+2 : path.item]
            content.text=controls[id]?["label"] as? String ?? (id=="openExample" ? "3DBenchy" : id)
            content.image=UIImage(systemName:["open":"folder.badge.plus","openExample":"sailboat","settings":"gearshape","feedback":"bubble.left","legal":"hand.raised"][id]!)
            cell.accessibilityIdentifier="form.sidebar."+id
        }
        content.textProperties.numberOfLines=collectionView === footerCollectionView ? 0 : 2;cell.contentConfiguration=content
        return cell
    }
    func collectionView(_ collectionView:UICollectionView,didSelectItemAt path:IndexPath) {
        let isModelRow=collectionView === self.collectionView && path.section==1
        if isModelRow {let row=rows[path.item];command?("select",row["id"] as? String ?? "",multi)}
        else {command?("command",actions[collectionView === footerCollectionView || path.section==2 ? path.item+2 : path.item],false)}
        if !isModelRow {collectionView.deselectItem(at:path,animated:true)}
    }
    func collectionView(_ collectionView:UICollectionView,didDeselectItemAt path:IndexPath) {
        guard collectionView === self.collectionView,path.section==1, rows.indices.contains(path.item) else {return}
        command?("select",rows[path.item]["id"] as? String ?? "",multi)
    }
    private func swipes(_ path:IndexPath)->UISwipeActionsConfiguration? {
        guard path.section==1, rows.indices.contains(path.item), rows[path.item]["kind"] as? String != "all" else {return nil}
        let row=rows[path.item],id=row["id"] as? String ?? ""
        let eye=UIContextualAction(style:.normal,title:german ? "Sichtbarkeit":"Visibility") { [weak self] _,_,done in self?.command?("visibility",id,false);done(true) }
        eye.image=UIImage(systemName:row["visible"] as? Bool == false ? "eye":"eye.slash")
        var actions=[eye]
        if row["removable"] as? Bool == true {
            let remove=UIContextualAction(style:.destructive,title:german ? "Entfernen":"Remove") { [weak self] _,_,done in self?.command?("remove",id,false);done(true) }
            remove.image=UIImage(systemName:"trash");actions.append(remove)
        }
        let config=UISwipeActionsConfiguration(actions:actions);config.performsFirstActionWithFullSwipe=false;return config
    }
    func collectionView(_ collectionView:UICollectionView,contextMenuConfigurationForItemAt path:IndexPath,point:CGPoint)->UIContextMenuConfiguration? {
        guard path.section==1,rows.indices.contains(path.item), rows[path.item]["kind"] as? String != "all" else {return nil}
        let row=rows[path.item],id=row["id"] as? String ?? ""
        return UIContextMenuConfiguration(identifier:nil,previewProvider:nil) { [weak self] _ in
            guard let self else {return nil}
            var items=[UIAction(title:self.german ? "Sichtbarkeit":"Visibility",image:UIImage(systemName:"eye")) { _ in self.command?("visibility",id,false) }]
            if row["removable"] as? Bool == true {items.append(UIAction(title:self.german ? "Entfernen":"Remove",image:UIImage(systemName:"trash"),attributes:.destructive) { _ in self.command?("remove",id,false) })}
            return UIMenu(children:items)
        }
    }
}
