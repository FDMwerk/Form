import UIKit
import WebKit
import UniformTypeIdentifiers

@main
final class MobileApp: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Viewer", sessionRole: session.role)
        configuration.delegateClass = MobileScene.self
        return configuration
    }
}

final class MobileScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let workspace = MobileWorkspaceController()
    private var viewer:MobileViewerController {workspace.viewer}
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: scene); window?.rootViewController = workspace; window?.makeKeyAndVisible()
        viewer.enqueue(options.urlContexts.map(\.url).filter(MobileFilePolicy.accepts))
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--example"), let url = Bundle.main.url(forResource: "3DBenchy", withExtension: "stl", subdirectory: "Examples") { viewer.enqueue([url]) }
        #endif
    }
    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        viewer.enqueue(contexts.map(\.url).filter(MobileFilePolicy.accepts))
    }
}

/// These are model imports, never arbitrary remote webpage downloads.
enum MobileFilePolicy {
    static let extensions = ["stl", "step", "stp", "iges", "igs", "brep", "brp", "obj", "ply", "3mf", "glb", "gltf"]
    static let maxBytes = 100 * 1024 * 1024
    static func accepts(_ url: URL) -> Bool { url.isFileURL && extensions.contains(url.pathExtension.lowercased()) }
}

private final class WeakMobileHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) {self.target=target}
    func userContentController(_ controller:WKUserContentController,didReceive message:WKScriptMessage) {target?.userContentController(controller,didReceive:message)}
}

final class MobileViewerController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, UIDocumentPickerDelegate {
    private(set) var web: WKWebView!
    private(set) var ready=false
    private(set) var latestState:[String:Any]=[:]
    let modelSidebar=ModelSidebarController()
    private var importing=false
    private var pending:[URL]=[]
    private var sources:[String:URL]=[:]
    private var exampleSources=Set<String>()
    private let reader=DispatchQueue(label:"de.fdmwerk.form.mobile.import",qos:.userInitiated)
    private let preferenceKey="FormMobileViewportPreferences"
    private let sessionDirectory=FileManager.default.temporaryDirectory.appendingPathComponent("Form-"+UUID().uuidString,isDirectory:true)
    private weak var activePanel: NativePanelController?
    private var activePanelID:String?
    private var lastChrome:NSDictionary?
    private var presentationHost:UIViewController {viewIfLoaded?.window != nil ? self : modelSidebar}
    private let notice=UILabel()
    private var lastNotice=""
    var german:Bool {(latestState["language"] as? String ?? Locale.preferredLanguages.first ?? "en").hasPrefix("de")}
    func sourceURL(for id:String)->URL? {sources[id]}
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor = .systemBackground
        let configuration=WKWebViewConfiguration();configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(WeakMobileHandler(self),name:"native")
        configuration.userContentController.addUserScript(WKUserScript(source:"window.FORM_NATIVE_SIDEBAR=true;window.FORM_NATIVE_UI=true;",injectionTime:.atDocumentStart,forMainFrameOnly:true))
        for (name,ext) in [("viewport","css"),("viewport","js"),("native-chrome","js"),("sidebar","js")] {
            guard let url=Bundle.main.url(forResource:name,withExtension:ext),let content=try? String(contentsOf:url) else {continue}
            var script=content
            if ext=="css",let data=try? JSONSerialization.data(withJSONObject:[content]),let literal=String(data:data,encoding:.utf8) {
                script="const nativeStyle=document.createElement('style');nativeStyle.textContent=\(literal)[0];document.head.appendChild(nativeStyle);"
            }
            configuration.userContentController.addUserScript(WKUserScript(source:script,injectionTime:.atDocumentEnd,forMainFrameOnly:true))
        }
        web=WKWebView(frame:.zero,configuration:configuration);web.navigationDelegate=self
        web.scrollView.isScrollEnabled=false;web.scrollView.contentInsetAdjustmentBehavior = .never;web.isOpaque=false;web.translatesAutoresizingMaskIntoConstraints=false
        view.addSubview(web)
        let annotationPress=UILongPressGestureRecognizer(target:self,action:#selector(annotationMenu(_:)));annotationPress.cancelsTouchesInView=false;annotationPress.allowableMovement=8;web.addGestureRecognizer(annotationPress)
        NSLayoutConstraint.activate([web.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor),web.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor),web.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),web.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor)])
        notice.numberOfLines=0;notice.textAlignment = .center;notice.font = .preferredFont(forTextStyle:.footnote);notice.adjustsFontForContentSizeCategory=true
        notice.backgroundColor = .secondarySystemBackground;notice.textColor = .label;notice.layer.cornerRadius=14;notice.clipsToBounds=true;notice.isHidden=true;notice.translatesAutoresizingMaskIntoConstraints=false
        view.addSubview(notice)
        NSLayoutConstraint.activate([notice.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),notice.centerXAnchor.constraint(equalTo:view.centerXAnchor),notice.widthAnchor.constraint(lessThanOrEqualTo:view.widthAnchor,multiplier:0.9),notice.heightAnchor.constraint(greaterThanOrEqualToConstant:40)])
        modelSidebar.command = { [weak self] action,id,multi in
            guard let self else {return}
            if action=="command" {self.performMobileCommand(id)}
            else {
                self.web.callAsyncJavaScript("window.formNative?.sidebarAction(action,id,multi)",arguments:["action":action,"id":id,"multi":multi],in:nil,in:.page) {_ in self.refreshNativeState()}
                if action=="select",!multi {self.splitViewController?.show(.secondary)}
            }
        }
        updateChrome()
        guard let url=Bundle.main.url(forResource:"index",withExtension:"html",subdirectory:"Web") else {showError("Missing viewer resources");return}
        web.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())
    }
    override func viewWillAppear(_ animated:Bool) {super.viewWillAppear(animated);navigationController?.setToolbarHidden(false,animated:animated);updateChrome()}
    func refreshNativeState() {
        guard ready else {return}
        web.callAsyncJavaScript("return window.formNative?.snapshot()",arguments:[:],in:nil,in:.page) { [weak self] result in
            if case .success(let value)=result,let state=value as? [String:Any] {self?.receive(state)}
        }
    }
    private func receive(_ state:[String:Any]) {
        latestState=state;updateChrome()
        modelSidebar.setState(state["sidebar"] as? [String:Any] ?? [:],controls:state["controls"] as? [String:[String:Any]] ?? [:],german:german)
        if let id=activePanelID,let descriptor=(state["panels"] as? [String:[String:Any]])?[id],let sections=descriptor["sections"] as? [[String:Any]] {activePanel?.update(sections:sections)}
        let status=(state["status"] as? [String:Any])?["text"] as? String ?? ""
        if !status.isEmpty,status != lastNotice {UIAccessibility.post(notification:.announcement,argument:status)}
        lastNotice=status
        notice.text=status.isEmpty ? nil : "  "+status+"  ";notice.isHidden=status.isEmpty
    }
    func label(_ id:String,_ fallback:String)->String {((latestState["controls"] as? [String:[String:Any]])?[id]?["label"] as? String).flatMap {$0.isEmpty ? nil:$0} ?? fallback}
    private func enabled(_ id:String)->Bool {
        guard ready,!importing else {return false}
        if let value=(latestState["controls"] as? [String:[String:Any]])?[id]?["enabled"] as? Bool {return value}
        for panel in (latestState["panels"] as? [String:[String:Any]] ?? [:]).values {
            for section in panel["sections"] as? [[String:Any]] ?? [] {
                if let item=(section["items"] as? [[String:Any]])?.first(where: {$0["id"] as? String==id}) {return item["enabled"] as? Bool ?? true}
            }
        }
        return false
    }
    private func button(_ id:String,_ image:String,_ fallback:String)->UIBarButtonItem {
        let button=UIBarButtonItem(title:nil,image:UIImage(systemName:image),primaryAction:UIAction(title:label(id,fallback)) {[weak self] _ in self?.performMobileCommand(id)})
        button.accessibilityLabel=label(id,fallback);button.accessibilityIdentifier="form."+id
        button.isEnabled=["open","side"].contains(id) ? ready : enabled(id)
        if (latestState["controls"] as? [String:[String:Any]])?[id]?["active"] as? Bool == true {button.tintColor = .systemGreen;button.accessibilityTraits.insert(.selected)}
        return button
    }
    private func menuAction(_ id:String,_ image:String,_ fallback:String)->UIAction {
        UIAction(title:label(id,fallback),image:UIImage(systemName:image),attributes:enabled(id) ? []:[.disabled]) {[weak self] _ in self?.performMobileCommand(id)}
    }
    private func updateChrome() {
        guard isViewLoaded else {return}
        let controls=latestState["controls"] as? [String:[String:Any]] ?? [:]
        let fingerprint:[String:Any]=["controls":controls,"title":latestState["title"] ?? "", "ready":ready,"importing":importing]
        guard lastChrome?.isEqual(to:fingerprint) != true else {return};lastChrome=fingerprint as NSDictionary
        navigationItem.title=importing ? (german ? "Wird geöffnet …":"Opening …") : (latestState["title"] as? String ?? "Form")
        navigationItem.largeTitleDisplayMode = .never
        let sidebarButton=splitViewController?.displayModeButtonItem ?? button("side","sidebar.left",german ? "Modelle":"Models")
        sidebarButton.accessibilityIdentifier="form.side";sidebarButton.accessibilityLabel=german ? "Modelle":"Models"
        navigationItem.leftBarButtonItems=[sidebarButton,button("open","plus",german ? "Öffnen":"Open")]
        navigationItem.rightBarButtonItems=[button("open-with","square.and.arrow.up",german ? "Teilen":"Share"),button("info","info.circle",german ? "Informationen":"Information")]
        let edit=UIBarButtonItem(title:nil,image:UIImage(systemName:"move.3d"),primaryAction:nil,menu:UIMenu(children:[menuAction("translate","arrow.up.and.down.and.arrow.left.and.right",german ? "Verschieben":"Move"),menuAction("rotate","rotate.3d",german ? "Drehen":"Rotate"),menuAction("explode","square.stack.3d.up",german ? "Explodieren":"Explode"),menuAction("model-tools","wrench.and.screwdriver",german ? "Position & Andocken":"Position & docking"),menuAction("scene-settings","slider.horizontal.3",german ? "Darstellung":"Appearance"),menuAction("undo","arrow.uturn.backward",german ? "Rückgängig":"Undo")]))
        edit.accessibilityLabel=german ? "Modellwerkzeuge":"Model tools";edit.accessibilityIdentifier="form.model-tools";edit.isEnabled=enabled("model-tools")
        let viewButton=UIBarButtonItem(title:nil,image:UIImage(systemName:"cube"),primaryAction:UIAction(title:german ? "Ansicht":"View") {[weak self] _ in self?.showPanel("display")})
        viewButton.accessibilityLabel=german ? "Ansicht":"View";viewButton.accessibilityIdentifier="form.view-tools"
        let options=UIBarButtonItem(title:nil,image:UIImage(systemName:"slider.horizontal.3"),primaryAction:UIAction(title:german ? "Messoptionen":"Measurement options") {[weak self] _ in self?.showPanel("measure")})
        options.accessibilityLabel=german ? "Messoptionen":"Measurement options";options.accessibilityIdentifier="form.measurement-tools";options.isEnabled=enabled("measure")
        let ruler=button("measure","ruler",german ? "Messen":"Measure")
        ruler.menu=UIMenu(children:[menuAction("native-measure-action-finish","checkmark",german ? "Messung abschließen":"Finish measurement"),menuAction("native-measure-action-cancel","xmark",german ? "Messpunkte verwerfen":"Cancel points")])
        toolbarItems=[button("fit","viewfinder",german ? "Einpassen":"Fit"),viewButton,UIBarButtonItem(systemItem:.flexibleSpace),ruler,options,button("cut","square.split.2x1",german ? "Schnitt":"Section"),UIBarButtonItem(systemItem:.flexibleSpace),edit]
        navigationController?.setToolbarHidden(false,animated:false)
        if !ready || importing {
            var config=UIContentUnavailableConfiguration.loading();config.text=german ? "Modell wird vorbereitet":"Preparing model"
            contentUnavailableConfiguration=config
        } else if latestState["hasModels"] as? Bool != true {
            var config=UIContentUnavailableConfiguration.empty();config.image=UIImage(systemName:"cube.transparent");config.text=german ? "Deine Modelle. In Form.":"Your models. In Form."
            config.secondaryText=german ? "3D-Dateien öffnen, ansehen und prüfen. Direkt auf deinem Gerät.":"Open, explore and inspect 3D files. Right on your device."
            config.button.title=german ? "Datei öffnen":"Open file";config.button=UIButton.Configuration.filled()
            config.button.title=german ? "Datei öffnen":"Open file"
            config.buttonProperties.primaryAction=UIAction {[weak self] _ in self?.performMobileCommand("open")}
            config.secondaryButton.title=german ? "3DBenchy ausprobieren":"Try 3DBenchy"
            config.secondaryButtonProperties.primaryAction=UIAction {[weak self] _ in self?.performMobileCommand("openExample")}
            contentUnavailableConfiguration=config
        } else {contentUnavailableConfiguration=nil}
    }
    func performMobileCommand(_ command:String) {
        if command=="side" {splitViewController?.show(.primary);return}
        if command=="open" {openPicker();return}
        if command=="openExample" {if let url=Bundle.main.url(forResource:"3DBenchy",withExtension:"stl",subdirectory:"Examples") {enqueue([url]);splitViewController?.show(.secondary)};return}
        if command=="info" {showFileInformation();return}
        if command=="open-with" {shareSelected();return}
        if command=="legal" {showLegal();return}
        if command=="feedback" {showFeedback();return}
        let panels=["settings":"settings","scene-settings":"appearance","background-menu":"background","display-menu":"display","model-tools":"position","explode":"explode"]
        if let panel=panels[command] {showPanel(panel);return}
        execute(command)
        if command=="cut" {showPanel("cut")}
    }
    private func execute(_ command:String) {
        web.callAsyncJavaScript("return window.formNative?.command(command)",arguments:["command":command],in:nil,in:.page) {_ in self.refreshNativeState()}
    }
    func showPanel(_ requestedID:String) {
        let aliases=["display":"view","background":"view","measure":"measurement","cut":"section","position":"model","explode":"model"]
        let id=aliases[requestedID] ?? requestedID
        guard ready,presentationHost.presentedViewController==nil else {return}
        refreshNativeState()
        guard let descriptor=(latestState["panels"] as? [String:[String:Any]])?[id],let sections=descriptor["sections"] as? [[String:Any]] else {return}
        let panel=NativePanelController(title:descriptor["title"] as? String ?? id,sections:sections) {[weak self] key,value in
            guard let self else {return}
            if let value {self.web.callAsyncJavaScript("return window.formNative?.set(id,value)",arguments:["id":key,"value":value],in:nil,in:.page) {_ in self.refreshNativeState()}}
            else {self.execute(key)}
        }
        activePanel=panel;activePanelID=id;presentSheet(panel,compact:id != "settings")
    }
    private func presentSheet(_ controller:UIViewController,compact:Bool=true) {
        let navigation=UINavigationController(rootViewController:controller);navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents=compact ? [.medium(),.large()]:[.large()]
        navigation.sheetPresentationController?.prefersGrabberVisible=true;navigation.sheetPresentationController?.prefersScrollingExpandsWhenScrolledToEdge=true
        presentationHost.present(navigation,animated:true)
    }
    @objc private func annotationMenu(_ gesture:UILongPressGestureRecognizer) {
        guard gesture.state == .began,gesture.numberOfTouches==1,presentationHost.presentedViewController==nil else {return}
        let location=gesture.location(in:web)
        web.callAsyncJavaScript("return document.elementFromPoint(x,y)?.closest('.measurement-label')?.dataset.measureId ?? null",arguments:["x":location.x,"y":location.y],in:nil,in:.page) {result in
            guard case .success(let value)=result,let id=value as? String else {return}
            let menu=UIAlertController(title:self.german ? "Messung":"Measurement",message:nil,preferredStyle:.actionSheet)
            menu.addAction(UIAlertAction(title:self.german ? "Messung löschen":"Delete measurement",style:.destructive) {_ in
                self.web.callAsyncJavaScript("window.formNative.sidebarAction('remove',id,false)",arguments:["id":"measurement:"+id],in:nil,in:.page) {_ in self.refreshNativeState()}
            })
            menu.addAction(UIAlertAction(title:self.german ? "Abbrechen":"Cancel",style:.cancel))
            menu.popoverPresentationController?.sourceView=self.web;menu.popoverPresentationController?.sourceRect=CGRect(x:location.x,y:location.y,width:1,height:1)
            self.presentationHost.present(menu,animated:true)
        }
    }
    func enqueue(_ urls: [URL]) {
        pending.append(contentsOf: urls)
        if isViewLoaded { drain() }
    }
    private func drain() {
        guard ready, !importing, !pending.isEmpty else { return }
        let url = pending.removeFirst()
        guard MobileFilePolicy.accepts(url) else { showError("Unsupported 3D file."); drain(); return }
        importing = true;updateChrome()
        let destination = sessionDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true).appendingPathComponent(url.lastPathComponent)
        reader.async {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                var coordinatedError: NSError?
                var readResult: Result<Data, Error>?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatedError) { coordinated in
                    readResult = Result {
                        let size = try coordinated.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                        guard size.isRegularFile == true, (size.fileSize ?? Int.max) <= MobileFilePolicy.maxBytes else { throw CocoaError(.fileReadTooLarge) }
                        let data = try Data(contentsOf: coordinated)
                        guard data.count <= MobileFilePolicy.maxBytes else { throw CocoaError(.fileReadTooLarge) }
                        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try data.write(to: destination, options: .atomic)
                        return data
                    }
                }
                if let error = coordinatedError { throw error }
                guard let result = readResult else { throw CocoaError(.fileReadUnknown) }
                let data = try result.get()
                DispatchQueue.main.async {
                    let id = UUID().uuidString
                    self.web.callAsyncJavaScript("return await window.openModel(name, bytes, sourceID)", arguments: ["name": url.lastPathComponent, "bytes": data.base64EncodedString(), "sourceID": id], in: nil, in: .page) { result in
                        if case .success(let value) = result, (value as? Bool) == true { self.sources[id] = destination; if url == Bundle.main.url(forResource: "3DBenchy", withExtension: "stl", subdirectory: "Examples") { self.exampleSources.insert(id) } }
                        else { try? FileManager.default.removeItem(at: destination.deletingLastPathComponent()) }
                        self.importing = false; self.refreshNativeState(); self.drain()
                    }
                }
            } catch {
                DispatchQueue.main.async { self.importing = false; self.updateChrome(); self.showError(error.localizedDescription); self.drain() }
            }
        }
    }
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
        guard message.frameInfo.isMainFrame,message.webView===web,message.frameInfo.request.url?.isFileURL==true else {return}
        if let object=message.body as? [String:Any] {
            if object["type"] as? String == "mobileChromeState",let state=object["state"] as? [String:Any] {receive(state)}
            if object["type"] as? String == "viewportPreferences",let value=object["value"] as? [String:Any],JSONSerialization.isValidJSONObject(value) {UserDefaults.standard.set(value,forKey:preferenceKey)}
            if object["type"] as? String == "saveScreenshot",let png=object["png"] as? String,png.count<64*1024*1024,let data=Data(base64Encoded:png),let image=UIImage(data:data) {share([image])}
            return
        }
        switch message.body as? String {
        case "ready":
            guard !ready else {return}
            let prefs=UserDefaults.standard.dictionary(forKey:preferenceKey) ?? [:]
            web.callAsyncJavaScript("window.applySystemLanguages(languages);window.applyViewportSettings(preferences);window.applyNativeCapabilities({externalSliceEstimate:false,blenderImport:false,donations:false});window.applyPrintSoftware([])",arguments:["languages":Locale.preferredLanguages,"preferences":prefs],in:nil,in:.page) {result in
                guard case .success=result else {self.showError("Viewer initialization failed");return}
                self.ready=true;self.refreshNativeState();self.drain()
            }
        case "openExample":performMobileCommand("openExample")
        case "open":openPicker()
        case "loaded":refreshNativeState()
        case "openWith","openInSlicer":shareSelected()
        case "legal":showLegal()
        case "feedback":showFeedback()
        default:break
        }
    }
    private func openPicker() {
        guard ready,presentationHost.presentedViewController==nil else {return}
        let picker=UIDocumentPickerViewController(forOpeningContentTypes:MobileFilePolicy.extensions.compactMap {UTType(filenameExtension:$0)},asCopy:true)
        picker.allowsMultipleSelection=true;picker.delegate=self;presentationHost.present(picker,animated:true)
    }
    func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]) {enqueue(urls);splitViewController?.show(.secondary)}
    private func shareSelected() {
        web.callAsyncJavaScript("return window.selectedSourceID()",arguments:[:],in:nil,in:.page) {result in
            guard case .success(let value)=result,let id=value as? String,let url=self.sources[id] else {return}
            var items:[Any]=[url];if self.exampleSources.contains(id),let credit=Bundle.main.url(forResource:"ATTRIBUTION",withExtension:"txt",subdirectory:"Examples") {items.append(credit)}
            self.share(items)
        }
    }
    private func showLegal() {
        guard presentedViewController==nil else {return}
        let controller=UIViewController();controller.title=german ? "Datenschutz & Lizenzen":"Privacy & licenses"
        let text=UITextView();text.isEditable=false;text.font = .preferredFont(forTextStyle:.body);text.adjustsFontForContentSizeCategory=true;text.dataDetectorTypes = .link
        text.textContainerInset=UIEdgeInsets(top:24,left:20,bottom:24,right:20)
        text.text="Form · FDMwerk\nsupport@fdmwerk.de\n\n"+(german ? "Deine Modelle bleiben auf deinem Gerät. Keine automatische Übertragung, keine Werbung und keine Analyse. Dateien und Screenshots werden erst über Apples Teilen-Dialog weitergegeben. Einstellungen und temporäre Sitzungskopien werden lokal gespeichert.":"Models are processed locally. No automatic upload, ads or analytics. Sharing is user initiated through Apple's share sheet. Settings and temporary session copies remain local.")+"\n\n3DBenchy © CreativeTools · Bambu Lab / MakerWorld 40146\nCC BY-ND 4.0 · Unchanged original model mesh serialized as STL.\nhttps://creativecommons.org/licenses/by-nd/4.0/\nhttps://makerworld.com/de/models/40146-benchy-bambu-pla-basic\n\nForm code: MIT\nThree.js: MIT · Lucide: ISC · fflate: MIT\nocct-import-js / Open CASCADE: LGPL 2.1 + OCCT exception\nhttps://github.com/FDMwerk/Form"
        let licenses=[("Three.js","three.txt"),("Lucide","lucide.txt"),("fflate","fflate.txt"),("occt-import-js","license.occt-import-js.txt"),("Open CASCADE","license.occt.txt"),("OCCT exception","OCCT_LGPL_EXCEPTION.txt")]
        controller.navigationItem.leftBarButtonItem=UIBarButtonItem(title:"Open Source",image:UIImage(systemName:"doc.text"),menu:UIMenu(children:licenses.map {title,file in
            UIAction(title:title) {[weak controller] _ in
                guard let url=Bundle.main.resourceURL?.appendingPathComponent("Web/licenses/"+file),let value=try? String(contentsOf:url) else {return}
                let detail=UIViewController();detail.title=title;let text=UITextView();text.isEditable=false;text.font = .preferredFont(forTextStyle:.body);text.adjustsFontForContentSizeCategory=true;text.text=value;text.textContainerInset=UIEdgeInsets(top:20,left:20,bottom:20,right:20);detail.view=text
                controller?.navigationController?.pushViewController(detail,animated:true)
            }
        }))
        controller.view=text;controller.navigationItem.rightBarButtonItem=UIBarButtonItem(systemItem:.done,primaryAction:UIAction {[weak controller] _ in controller?.dismiss(animated:true)})
        presentSheet(controller,compact:false)
    }
    private func showFeedback() {
        guard presentedViewController==nil else {return}
        let alert=UIAlertController(title:label("feedback","Feedback"),message:nil,preferredStyle:.actionSheet)
        for (title,url) in [("E-Mail","mailto:support@fdmwerk.de?subject=Form%20Feedback"),("GitHub","https://github.com/FDMwerk/Form/issues")] {alert.addAction(UIAlertAction(title:title,style:.default) {_ in if let url=URL(string:url) {UIApplication.shared.open(url)}})}
        alert.addAction(UIAlertAction(title:german ? "Abbrechen":"Cancel",style:.cancel))
        alert.popoverPresentationController?.sourceView=view;alert.popoverPresentationController?.sourceRect=CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1)
        presentationHost.present(alert,animated:true)
    }
    func showFileInformation() {
        guard ready, presentedViewController == nil else { return }
        let script = """
        return {title:document.getElementById('info').getAttribute('aria-label'),german:document.documentElement.lang.startsWith('de'),note:document.getElementById('volume-note').textContent,rows:[...document.querySelectorAll('#file-info .info-row')].map(row=>({label:row.firstElementChild.textContent,value:row.lastElementChild.textContent,metric:/[0-9].*(?:mm|cm|µm|cm³|m|in|ft)$/.test(row.lastElementChild.textContent)?'true':'false'}))};
        """
        web.callAsyncJavaScript(script, arguments:[:], in:nil, in:.page) { result in
            guard case .success(let value) = result, let info = value as? [String:Any] else { return }
            let controller = FileInformationController(title:info["title"] as? String ?? "Information",rows:info["rows"] as? [[String:String]] ?? [],note:info["note"] as? String ?? "",german:info["german"] as? Bool == true)
            controller.navigationItem.leftBarButtonItem=UIBarButtonItem(title:self.german ? "3D-Druck":"3D printing",image:UIImage(systemName:"cube.box"),primaryAction:UIAction {[weak self,weak controller] _ in controller?.dismiss(animated:true) {self?.showPanel("print")}})
            let navigation=UINavigationController(rootViewController:controller)
            navigation.modalPresentationStyle = .pageSheet
            navigation.sheetPresentationController?.detents=[.medium(),.large()]
            navigation.sheetPresentationController?.prefersGrabberVisible=true
            self.present(navigation,animated:true)
        }
    }
    private func share(_ items: [Any]) {
        guard presentedViewController == nil else { return }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = view
        controller.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: 44, width: 1, height: 1)
        present(controller, animated: true)
    }
    private func showError(_ message: String) {
        guard isViewLoaded, presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Form", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        // Only bundled content is allowed to run with access to the native bridge.
        if url.isFileURL, let root = Bundle.main.resourceURL?.standardizedFileURL.path, url.standardizedFileURL.path.hasPrefix(root + "/") { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false; importing = false
        showError("The viewer ran out of resources. Reopen your models after restarting Form.")
    }
}
