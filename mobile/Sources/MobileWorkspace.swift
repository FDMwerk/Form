import UIKit

/// Standard Apple column navigation adapts between iPad windows and iPhone stacks.
final class MobileWorkspaceController: UISplitViewController, UISplitViewControllerDelegate {
    let viewer=MobileViewerController()
    init() {
        super.init(style:.doubleColumn)
        delegate=self;preferredDisplayMode = .oneBesideSecondary;preferredSplitBehavior = .tile
        minimumPrimaryColumnWidth=260;maximumPrimaryColumnWidth=360;preferredPrimaryColumnWidthFraction=0.28
        let library=UINavigationController(rootViewController:viewer.modelSidebar)
        let detail=UINavigationController(rootViewController:viewer)
        detail.setToolbarHidden(false,animated:false)
        setViewController(library,for:.primary);setViewController(detail,for:.secondary)
    }
    required init?(coder:NSCoder) {fatalError("init(coder:) unavailable")}
    func splitViewController(_ svc:UISplitViewController,topColumnForCollapsingToProposedTopColumn proposedTopColumn:UISplitViewController.Column)->UISplitViewController.Column {.secondary}
}
