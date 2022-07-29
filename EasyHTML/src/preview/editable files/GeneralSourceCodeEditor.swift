import UIKit

class GeneralSourceCodeEditor: UITabBarController, UITabBarControllerDelegate, NotificationHandler, FileEditor {
    
    static func forExt(_ ext: String) -> GeneralSourceCodeEditor {
        //let ext = ext.lowercased()
        
//        if ext == "py" {
//            return PythonEditorController()
//        } else {
            return WebEditorController()
//        }
    }
    
    static let identifier = "editor"
    
    final func canHandleMessage(message: EditorMessage) -> Bool {
        switch message {
        case .save, .fileMoved, .close, .focus, .blur: return true
        case .custom(let code):
            if code == EDITOR_UPDATE_FONT_SIZE {
                return true
            }
            if code == EDITOR_ENABLE_LOW_ENERGY_MODE {
                return true
            }
            if code == EDITOR_DISABLE_LOW_ENERGY_MODE {
                return true
            }
            return false
        }
    }
    
    final func handleMessage(message: EditorMessage, userInfo: Any?) {
        switch message {
        case .save:
            dispatcher.save()
            save()
            break;
        case .fileMoved:
            
            guard let destinationURL = userInfo as? URL else { return }
            
            let name = destinationURL.lastPathComponent
            
            editor.file!.url = destinationURL
            setTitle(name)
            
            dispatcher.notifyFileMoved()
            
            fileMoved()
            
            break;
        case .close:
            close()
            dispatcher.observerClosed(observer: self)
            break;
        case .custom(let code):
            if code == EDITOR_UPDATE_FONT_SIZE {
                editorViewController.updateFontSize()
            } else if code == EDITOR_ENABLE_LOW_ENERGY_MODE {
                enableLowEnergyMode()
            } else if code == EDITOR_DISABLE_LOW_ENERGY_MODE {
                disableLowEnergyMode()
            }
        case .focus:
            let bringUpKeyboard = (userInfo as? [String : Any])?[Editor.focusedByShortcutKey] as? Bool ?? false
            focusTab(index: selectedIndex, bringUpKeyboard: bringUpKeyboard)
        case .blur:
            save()
        }
        
    }
    
    func fileMoved() {
        
    }
    
    func save(callback: (() -> ())? = nil) {
        
    }
    
    func close() {
        
    }
    
    func focusTab(index: Int, bringUpKeyboard: Bool) {
        if index == 0 {
            editorViewController.focus()
            if(bringUpKeyboard) {
                editorViewController.showKeyboard()
            }
        }
    }
    
    final func applyConfiguration(config: EditorConfiguration) {
        guard let editor = config[.editor] as? Editor else {
            fatalError()
        }
        
        self.editor = editor
        self.dispatcher.file = editor.file
        
        if let isReadonly = config[.isReadonly] as? Bool {
            dispatcher.isReadonly = isReadonly
        }
        if let encoding = config[.textEncoding] as? String.Encoding {
            dispatcher.textEncoding = encoding
        }
        if let ioManager = config[.ioManager] as? Editor.IOManager {
            dispatcher.ioManager = ioManager
        } else {
            dispatcher.ioManager = Editor.IOManager()
        }
        
        var i = 0
        createTabs()
        for controller in editorSession.viewControllers {
            if controller.tabBarController == nil {
                selectedIndex = i
                updateClaim(index: i)
                break
            }
            i += 1
        }
    }
    
    private var switchModeButton: PrimarySplitViewControllerModeButton!
    
    internal var editor: Editor! = nil {
        didSet {
            configure(editor: editor)
        }
    }
    
    internal var dispatcher: SourceCodeEditorSessionDispatcher! {
        return editorSession?.sessionDispatcher
    }
    
    internal var editorSession: SourceCodeEditorSession!
    internal var editorViewController: EditorViewController {
        return editorSession.viewControllers[0] as! EditorViewController
    }
    
    @objc func toggleFullscreen() {
        switchModeButton.toggle()
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: "f", modifierFlags: [.control,.command], action: #selector(toggleFullscreen), discoverabilityTitle: localize("togglefullscreen", .editor))
        ]
    }
    
    @objc func back(sender: UIBarButtonItem)
    {
        self.parent!.dismiss(animated: true, completion: nil)
    }
    
    final func setTitle(_ title: String) {
        self.title = editor?.file?.name ?? localize("editor")
        self.titleButton.button.setTitle(title, for: .normal)
        (navigationController as? TabNavigationController)?.updateTitle()
        self.titleButton.updateSize()
    }
    
    
    var dummyControllers = [UIViewController]()
    
    func configure(editor: Editor) {
        
        self.editorSession = SourceCodeEditorSession.get(file: editor.file!)
        
        if editorSession.viewControllers.isEmpty {
            createDispatcher()
        }
        
        dispatcher.observers.append(self)
        
        setTitle(editor.file!.name)
        
        self.navigationItem.title = editor.file!.name
    }
    
    func createDispatcher() {
        editorSession.viewControllers = [
            EditorViewController()
        ]
        editorSession.sessionDispatcher = SourceCodeEditorSessionDispatcher()
        editorViewController.file = dispatcher.file
    }
    
    func createTabs() {
        dummyControllers = [
            UIViewController()
        ]
        viewControllers = dummyControllers
        
        updateTabBar()
    }
    
    func updateTabBar() {
        if let items = tabBar.items {
            items[0].title = localize("editor")
            items[0].isEnabled = true;
        }
    }
    
    func desintegrate() {
        dummyControllers[oldIndex].tabBarItem = viewControllers![oldIndex].tabBarItem
        viewControllers![oldIndex] = dummyControllers[oldIndex]
        viewControllers = dummyControllers
        editorSession = nil
    }
    
    func reclaim(index: Int, oldIndex: Int) {
        
        let controller = editorSession.viewControllers[index]
        let parent = controller.tabBarController

        if oldIndex >= 0 {
            dummyControllers[oldIndex].tabBarItem = viewControllers![oldIndex].tabBarItem
            viewControllers![oldIndex] = dummyControllers[oldIndex]
        }

        if parent != nil && parent != self, oldIndex >= 0 {
            if let view = parent as? GeneralSourceCodeEditor,
                let item = view.tabBar.items?[oldIndex] {
                view.tabBar(view.tabBar, didSelect: item)
                view.selectedIndex = oldIndex
            }
        }
        
        controller.tabBarItem = self.dummyControllers[index].tabBarItem
        self.viewControllers![index] = controller
        
        _ = controller.view
        updateTabBar()
    }
    
    private var oldIndex: Int = -1
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        updateClaim(index: tabBar.items?.firstIndex(of: item) ?? 0)
    }
    
    func updateClaim(index: Int) {
        if index == oldIndex {
            return
        }
        reclaim(index: index, oldIndex: oldIndex)
        oldIndex = index
        
        if UIDevice.current.produceSimpleHapticFeedback() {
            if #available(iOS 10.0, *) {
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()
            }
        }
    }
    
    @objc func titleTapped() {
        dispatcher.toggleExpanderView()
    }
    
    override func viewDidLoad() {
        
        self.edgesForExtendedLayout = []
        
        titleButton.button.addTarget(self, action: #selector(titleTapped), for: .touchUpInside)
        
        tabBar.barTintColor = userPreferences.currentTheme.tabBarBackgroundColor
        tabBar.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
        view.backgroundColor = userPreferences.currentTheme.background
        
        setupThemeChangedNotificationHandling()
        
        executeButton.target = self
    }
    
    func switchToExecuteHeader() {
        executeButton.isEnabled = isExecuteButtonEnabled
        
        if(PrimarySplitViewController.instance(for: view)!.isCollapsed) {
            self.navigationItem.rightBarButtonItems = [executeButton]
        } else {
            self.navigationItem.rightBarButtonItems = [switchModeButton, executeButton]
        }
        
        self.navigationItem.titleView = nil
    }
    
    func switchToEditorHeader() {
        if(PrimarySplitViewController.instance(for: view)!.isCollapsed) {
            self.navigationItem.rightBarButtonItems = []
        } else {
            self.navigationItem.rightBarButtonItems = [switchModeButton]
        }
        
        self.navigationItem.titleView = titleButton
        titleButton.updateSize()
    }
    
    @objc func reload(sender: UIBarButtonItem)
    {
        // Будет перезаписано подклассами
    }
    
    final var isExecuteButtonEnabled = true {
        didSet {
            executeButton.isEnabled = isExecuteButtonEnabled
        }
    }
    var titleButton = EditorTitleButtonView()
    
    private var executeButton: UIBarButtonItem = {
        let button = UIBarButtonItem()
        
        button.image = #imageLiteral(resourceName: "reload")
        button.action = #selector(reload)
        
        return button
    }()
    
    final func updateTheme() {
        
        tabBar.barTintColor = userPreferences.currentTheme.tabBarBackgroundColor
        tabBar.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
        view.backgroundColor = userPreferences.currentTheme.background
        
        editorViewController.updateTheme()
    }
    
    @objc func themeUpdated() {
        updateTheme()
    }
    
    private var appeared = false
    
    override func viewDidAppear(_ animated: Bool) {
        if !appeared {
            appeared = true
            switchModeButton = PrimarySplitViewControllerModeButton(window: view.window!)
            tabBar.isTranslucent = false
        }
    }
    
    func enableLowEnergyMode() {
        // Будет перезаписано подклассами
    }
    
    func disableLowEnergyMode() {
        // Будет перезаписано подклассами
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // Я перерыл весь гугл, но так и не нашел из-за чего
        // модальный TabViewController так глючит при перевороте экрана.
        
        tabBar.sizeToFit()
        tabBar.frame.origin.y = view.bounds.height - tabBar.frame.height
    }
    
    deinit {
        clearNotificationHandling()
    }
}
