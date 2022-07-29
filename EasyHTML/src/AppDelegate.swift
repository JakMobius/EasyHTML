import UIKit
import SwiftyDropbox

var _testing = false

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate, UISceneDelegate {
    
    internal var window: UIWindow?
    
    static func updateSceneTitle(for window: UIWindow) {
        if #available(iOS 13.0, *) {
            let splitViewController = PrimarySplitViewController.instance(for: window)
            
            if splitViewController!.isCollapsed && splitViewController!.displayMode != .primaryHidden {
                window.windowScene?.title = nil
            }
            
            let controller = PreviewContainer.activeSwitcherView(for: window)
            
            guard let tabView = controller.presentedView else {
                window.windowScene?.title = nil
                return
            }
            
            guard let editor = tabView.navController.editorViewController else {
                window.windowScene?.title = nil
                return
            }
            
            guard !(editor is NoEditorPreviewController) else {
                window.windowScene?.title = nil
                return
            }
            
            window.windowScene?.title = editor.title
        }
    }
    
    func applicationDidFinishLaunching(_ application: UIApplication) {

        
        _testing = CommandLine.arguments.contains("--uitesting")
        
        if(_testing) {
            FileBrowser.filesDir = "/files-testing";
            FileBrowser.filesFullPath = applicationPath + FileBrowser.filesDir
            try? FileManager.default.removeItem(atPath: FileBrowser.filesFullPath)
            try! FileManager.default.createDirectory(atPath: FileBrowser.filesFullPath, withIntermediateDirectories: false, attributes: [:])
        }
        
        BootUtils.readDeviceInfo()
        userPreferences.reload()
        BootUtils.initMenuController()
        userPreferences.applyTheme()
        BootUtils.setupWebViewKeyboardAppearance()
        BootUtils.deleteSharedFolderIfExist()
        
        print("[EasyHTML] Application path is " + applicationPath)
        
        if #available(iOS 13.0, *) {
            
        } else {
            var initialViewController: UIViewController
            
            
            let window = UIWindow()
            
            if BootUtils.isFirstLaunch {
                initialViewController = UIStoryboard(name: "WelcomeScreen", bundle: nil).instantiateViewController(withIdentifier: "main")
            } else {
                initialViewController = PrimarySplitViewController.instance(for: window)
            }
            
            window.rootViewController = initialViewController
            self.window = window
            window.makeKeyAndVisible()
        }
    }
    
    static func openURL(url: URL, in window: UIWindow! = nil) {
        if let authResult = DropboxClientsManager.handleRedirectURL(url) {
            
            switch authResult {
            case .success:
                DropboxFileListTableView.rootController.reloadDirectory()
                
            case .cancel:
                DropboxFileListTableView.isDropboxInitialized = false
                
                let controller = DropboxFileListTableView.rootController
                if let nc = controller?.navigationController {
                    if(controller == nc.topViewController) {
                        controller?.navigationController?.popViewController(animated: true)
                    }
                }
                
            case .error(_, let description):
                DropboxFileListTableView.isDropboxInitialized = false
                
                let alert = TCAlertController.getNew()
                
                alert.applyDefaultTheme()
                
                alert.addAction(action: TCAlertAction(text: "OK", shouldCloseAlert: true))
                
                alert.contentViewHeight = 130
                alert.constructView()
                alert.makeCloseableByTapOutside()
                alert.headerText = localize("dropboxerror")
                
                let textView = alert.addTextView()
                textView.text = localize("dropboxerrordesc") + "\n" + description
                
                alert.animation = TCAnimation(animations: [.scale(0.8, 0.8), .opacity], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.6)
                alert.closeAnimation = alert.animation
                
                
                
                let window = DropboxFileListTableView.rootController.view.window
                window!.addSubview(alert.view)
                
                let controller = DropboxFileListTableView.rootController
                if let nc = controller?.navigationController {
                    if(controller == nc.topViewController) {
                        controller?.navigationController?.popViewController(animated: true)
                    }
                }
            }
        } else if let authResult = GitHubAPI.handleRedirectURL(url) {
            if authResult {
                GitHubAPI.authorizationSucceeded()
            } else {
                GitHubAPI.authorizationFailed()
            }
        } else {
            receivedFile(at: url, window: window)
        }
    }
    
    static func receivedFile(at url: URL, window: UIWindow! = nil) {
        
        func tryAgain() {
            // Мне влом делать это правильно. Пусть будет так
            // Будет скучно - переделаю. #TODO
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.receivedFile(at: url)
            })
        }
        
        var window: UIWindow! = window
        
        if #available(iOS 13.0, *) {
            if window == nil {
                fatalError()
            }
        } else if window == nil {
            window = UIApplication.shared.delegate!.window!!
        }
        
        guard let instance = FolderPickerViewController.instance(for: window) else { tryAgain(); return }
        guard let fileListManager = instance.fileListManager else { tryAgain(); return }
        guard let split = PrimarySplitViewController.instance(for: window) else { tryAgain(); return }
        guard let previewContainer = PreviewContainer.instance(for: window) else { tryAgain(); return }
        
        // Приложение уже было запущено, кидаем файл в FileMovingManager
        

        let switcherView = PreviewContainer.activeSwitcherView(for: window)
        
        if(split.isCollapsed) {
            guard let container = split.smallScreenSwitcherView else { tryAgain(); return }
            guard let first = container.containerViews.first else { tryAgain(); return }
            container.animateIn(view: first)
        } else {
            guard let container = previewContainer.switcherView else { tryAgain(); return }
            guard let last = container.lastOpenedView ?? container.containerViews.first else { tryAgain(); return }
            container.animateIn(view: last)
        }
        
        var url = url
        var path = url.path
        
        if(path.hasPrefix("/private")) {
            path.removeFirst(8)
            url = URL(fileURLWithPath: path)
        }
        
        guard let file = FSNode.getLocalFile(globalURL: url) else {
            print("[EasyHTML] [AppDelegate] receivedFile(at:) File not exist!")
            return
        }
        
        if path.starts(with: FileBrowser.filesFullPath) {
            
            let e = url.pathExtension.lowercased()
            if(e == "zip" || e == "jar") {
                return
            }
            
            if let file = file as? FSNode.File {
                let editor = Editor.getEditor(configuration: [:], file: file, in: switcherView)
                let _: FileEditorController
                
                let config: EditorConfiguration = [.ioManager : Editor.IOManager()]
                
                if(Editor.imageExtensions.contains(e)) {
                    if editor.focusIf(fileIs: file, controllerIs: ImagePreviewController.self, animated: true) {
                        editor.openFile(file: file, using: ImagePreviewController(), with: config, in: switcherView)
                    }
                } else if(Editor.syntaxHighlightingSchemeFor(ext: e) != nil) {
                    if editor.focusIf(fileIs: file, controllerIs: WebEditorController.self, animated: true) {
                        editor.openFile(file: file, using: GeneralSourceCodeEditor.forExt(e), with: config, in: switcherView)
                    }
                } else {
                    if Editor.cacheNeededExtensions.contains(file.url.pathExtension) {
                        if editor.focusIf(fileIs: file, controllerIs: CacheNeededFilePreviewController.self) {
                            editor.openFile(file: file, using: CacheNeededFilePreviewController(), with: config, in: switcherView)
                        }
                    } else {
                        if editor.focusIf(fileIs: file, controllerIs: AnotherFilePreviewController.self) {
                            editor.openFile(file: file, using: AnotherFilePreviewController(), with: config, in: switcherView)
                        }
                    }
                }
            }
            
            return;
        }
        
        func showRelocationInterface() {
            
            let sourceContainer = ReceivedFilesContainer(url: url.deletingLastPathComponent())
            
            sourceContainer.fileListManager = fileListManager
            
            fileListManager.startMovingFiles(cells: nil, files: [file], from: sourceContainer)
            
            (fileListManager.parent.topViewController as? FileListController)?.tableView.reloadData()
            
            let instance = PrimarySplitViewController.instance(for: window)!
            
            if let switcher = instance.smallScreenSwitcherView {
                if(switcher.hasPrimaryTab && switcher.containerViews.count > 1) {
                    if(switcher.presentedView == nil) {
                        switcher.animateIn(animated: false, view: switcher.containerViews[0])
                    } else if(switcher.presentedView.index > 0) {
                        switcher.animateOut(animated: false, force: true) {
                            switcher.animateIn(animated: false, view: switcher.containerViews[0])
                        }
                    }
                }
            }
        }
        
        if let fileRelocationManager = fileListManager.filesRelocationManager {
            
            if fileRelocationManager.sourceContainer is ReceivedFilesContainer {
                fileRelocationManager.addFile(file: file)
            } else {
                
                fileRelocationManager.cancelFilesRelocation()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: showRelocationInterface)
            }
        } else {
            showRelocationInterface()
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        AppDelegate.openURL(url: url)
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        
        Editor.sendMessageToAllEditors(message: .save, userInfo: nil)
        
        userPreferences.statistics.save()
        
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        
        if let tab = PreviewContainer.activeSwitcherView().presentedView {
            tab.blured()
        }
        
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        if let tab = PreviewContainer.activeSwitcherView().presentedView {
            tab.focused()
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        Editor.sendMessageToAllEditors(message: .save, userInfo: nil)
        
        userPreferences.statistics.save()
        FileManager.default.clearTempDirectory()
        try? FileManager.default.removeItem(atPath: applicationPath + "/error report")
        
        Defaults.wipeTestingDefaults()
        
        if _testing {
            try? FileManager.default.removeItem(atPath: FileBrowser.filesFullPath)
        }
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        
        return configuration
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        for session in sceneSessions {
            
            let controller = session.userInfo?[PrimarySplitViewController.sceneUserInfoKey] as? PrimarySplitViewController
            
            controller?.view.window?.rootViewController = nil
        }
    }
}

