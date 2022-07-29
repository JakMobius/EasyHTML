import UIKit
import WebKit

/**
    Used to open text files and source codes.
 */

class WebEditorController: GeneralSourceCodeEditor {

//    override func editor(crashed editor: EditorViewController) {
//        super.editor(crashed: editor)
//        
//        browserViewController.tabBarItem.isEnabled = false
//        consoleViewController.tabBarItem.isEnabled = false
//    }

    override func close() {
        super.close()
        //editorViewController.handleClose()
    }

    override func focusTab(index: Int, bringUpKeyboard: Bool) {
        if (index == 0) {
            editorViewController.focus()
            if (bringUpKeyboard) {
                editorViewController.showKeyboard()
            }
        } else if (index == 1) {
            browserViewController.focus()
        } else if (index == 2) {
            consoleViewController!.focus()
        }
    }

    internal var browserViewController: WebViewController {
        editorSession.viewControllers[1] as! WebViewController
    }

    internal var consoleViewController: ConsoleViewController! {
        editorSession.viewControllers[2] as? ConsoleViewController
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //updateButton()
    }

    override func configure(editor: Editor) {
        super.configure(editor: editor)

        tabBar.barTintColor = userPreferences.currentTheme.tabBarBackgroundColor
        tabBar.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
        view.backgroundColor = userPreferences.currentTheme.background
    }

    override var dispatcher: WebEditorSessionDispatcher! {
        editorSession?.sessionDispatcher as? WebEditorSessionDispatcher
    }

    override func createDispatcher() {

        let dispatcher = WebEditorSessionDispatcher()
        editorSession.sessionDispatcher = dispatcher

        // editorSession.sessionDispatcher automatically
        // updates its session field, so dispatcher.file
        // and dispatcher.session can be used here safely.

        let editorViewController = EditorViewController()
        editorViewController.dispatcher = dispatcher
        editorViewController.delegate = dispatcher

        let webViewController = WebViewController()
        webViewController.dispatcher = dispatcher

        let consoleViewController = ConsoleViewController()
        consoleViewController.delegate = dispatcher

        consoleViewController.delegate = dispatcher
        editorViewController.delegate = dispatcher
        editorViewController.file = dispatcher.file

        editorSession.viewControllers = [
            editorViewController,
            webViewController,
            consoleViewController
        ]
    }

    override func createTabs() {

        dummyControllers = [
            UIViewController(),
            UIViewController(),
            UIViewController(),
        ]
        viewControllers = dummyControllers
    }

    override func updateTabBar() {
        if let items = tabBar.items {
            items[0].title = localize("editor")
            items[0].image = UIImage(named: "editor")
            items[1].title = localize("browser")
            items[1].image = UIImage(named: "browser")
            items[1].isEnabled = dispatcher.isBrowser
            items[2].title = localize("console")
            items[2].image = UIImage(named: "console")
            items[2].isEnabled = dispatcher.isScript
        }
    }

    override func reload(sender: UIBarButtonItem) {
        browserViewController.reload()
    }

    final func updateButton(selectedItem: Int = -1) {
        var selectedItem = selectedItem

        if (selectedItem == -1) {
            selectedItem = selectedIndex
        }

        if (selectedItem != 0) {
            switchToExecuteHeader()
        } else {
            switchToEditorHeader()
        }
    }

    private weak var lastSelectedController: UIViewController?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateButton()
    }

    let emptyViewController: UIViewController = {
        var controller = UIViewController()
        controller.tabBarItem = UITabBarItem()
        return controller
    }()

    override func enableLowEnergyMode() {
        guard lastSelectedController == nil else {
            return
        }

        // Help WKWebView to enable low energy mode

        view.isHidden = true

        viewControllers?.append(emptyViewController)

        lastSelectedController = selectedViewController
        selectedViewController = emptyViewController
    }

    override func disableLowEnergyMode() {
        view.isHidden = false

        viewControllers = Array(viewControllers![0...2])
        if let controller = lastSelectedController {
            selectedViewController = controller
            lastSelectedController = nil
        }
    }

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        super.tabBar(tabBar, didSelect: item)

        let selectedIndex = tabBar.items!.firstIndex(of: item) ?? -1

        updateButton(selectedItem: selectedIndex)

        switch selectedIndex {
        case 1: browserViewController.navigatedToPreview(); break;
        case 2: consoleViewController.navigatedToConsole(); break;
        default: break;
        }
    }

    deinit {
        clearNotificationHandling()
    }
}
