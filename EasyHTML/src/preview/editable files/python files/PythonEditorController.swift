//import UIKit
//import WebKit
//
///**
// Used to open python source codes.
// */
//
//class PythonEditorController: GeneralSourceCodeEditor, ConsoleDelegate {
//    
//    override func editor(crashed editor: EditorViewController) {
//        super.editor(crashed: editor)
//        
//        previewController.tabBarItem.isEnabled = false
//        consoleViewController.tabBarItem.isEnabled = false
//    }
//    
//    override func editor(loaded editor: EditorViewController) {
//        
//        super.editor(loaded: editor)
//        
//        consoleViewController.tabBarItem.isEnabled = true
//        previewController.tabBarItem.isEnabled = true
//    }
//    
//    func reloadConsole() {
//        
//    }
//    
//    func console(executed command: String) {
//        
//    }
//    
//    override func focusTab(index: Int, bringUpKeyboard: Bool) {
//        if(index == 0) {
//            editorViewController.focus()
//            if(bringUpKeyboard) {
//                editorViewController.showKeyboard()
//            }
//        } else if(index == 1) {
//            //previewController.focus()
//        } else if(index == 2) {
//            consoleViewController.focus()
//        }
//    }
//    
//    internal var previewController = PythonPreviewController()
//    internal var consoleViewController = ConsoleViewController()
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        updateButton()
//    }
//    
//    override func configure(editor: Editor) {
//        super.configure(editor: editor)
//        
//        tabBar.barTintColor = userPreferences.currentTheme.tabBarBackgroundColor
//        tabBar.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
//        view.backgroundColor = userPreferences.currentTheme.background
//        
//        previewController.file = self.file
//        
//        consoleViewController.delegate = self
//        
//        viewControllers = [
//            editorViewController,
//            previewController,
//            consoleViewController,
//        ]
//        
//        _ = consoleViewController.view
//        
//        if let items = tabBar.items {
//            items[0].title = localize("editor")
//            items[1].title = localize("browser")
//            items[2].title = localize("console")
//            
//            previewController.tabBarItem.isEnabled = false
//            consoleViewController.tabBarItem.isEnabled = false
//        }
//        
//        _ = previewController.view
//    }
//    
//    @objc override func reload(sender: UIBarButtonItem)
//    {
//        save(force: false) {
//            self.previewController.run()
//        }
//    }
//    
//    final func updateButton(selectedItem: Int = -1)
//    {
//        var selectedItem = selectedItem
//        
//        if(selectedItem == -1)
//        {
//            selectedItem = selectedIndex
//        }
//        
//        if(selectedItem != 0) {
//            switchToExecuteHeader()
//        } else {
//            switchToEditorHeader()
//        }
//    }
//    
//    private var lastSelectedController: UIViewController?
//    
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        updateButton()
//    }
//    
//    let emptyViewController: UIViewController = {
//        var controller = UIViewController()
//        controller.tabBarItem = UITabBarItem()
//        return controller
//    }()
//    
//    override func enableLowEnergyMode() {
//        guard lastSelectedController == nil else { return }
//        
//        view.isHidden = true
//        
//        viewControllers?.append(emptyViewController)
//        
//        lastSelectedController = selectedViewController
//        selectedViewController = emptyViewController
//    }
//    
//    override func disableLowEnergyMode() {
//        view.isHidden = false
//        
//        viewControllers = Array(viewControllers![0...2])
//        if let controller = lastSelectedController {
//            selectedViewController = controller
//            lastSelectedController = nil
//        }
//    }
//    
//    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem)
//    {
//        super.tabBar(tabBar, didSelect: item)
//        
//        let selectedIndex = tabBar.items!.firstIndex(of: item) ?? -1
//        
//        updateButton(selectedItem: selectedIndex)
//        
//        switch selectedIndex {
//        case 1: previewController.navigatedToPreview(); break;
//        case 2: consoleViewController.navigatedToConsole(); break;
//        default: break;
//        }
//    }
//    
//    deinit {
//        clearNotificationHandling()
//    }
//    
//}
