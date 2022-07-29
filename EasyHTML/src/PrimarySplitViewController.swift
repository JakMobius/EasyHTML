//
//  PrimarySplitViewController.swift
//  EasyHTML
//
//  Created by Артем on 07.10.17.
//  Copyright © 2017 Артем. All rights reserved.
//

import Foundation
import UIKit

class SmallScreenEditorSwitcherView: EditorSwitcherView {
    override var isCompact: Bool {
        return true
    }
    
    override var hasPrimaryTab: Bool {
        get {
            return true
        }
    }
}

class SmallScreenEditorTabView: EditorTabView {
    
    override func viewsDisappeared() {
        navController.topViewController?.view.isHidden = true
        
        //navController.screenshot()
    }
    
    override func viewsAppeared() {
        navController.topViewController?.view.isHidden = false
        
        //navController.placeholderImageView?.isHidden = true
        //navController.placeholderImageView?.image = nil
    }
    
    override init(frame: CGRect, navigationController: TabNavigationController) {
        super.init(frame: frame, navigationController: navigationController)
        
        navController.titleContainer.titleLabel.text = localize("files", .preferences)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

class PrimarySplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    
    var isLoaded = false
    public var fileToOpen: FSNode.File! = nil
    
    static var sceneUserInfoKey: String = "S"
    
    static func instance(for view: UIView!) -> PrimarySplitViewController! {
        
        if view == nil {
            return _instance
        }
        
        var window: UIWindow?
        
        if let view = view as? UIWindow {
            window = view
        } else {
            window = view.window
        }
        
        if #available(iOS 13.0, *) {
            
            guard let session = window?.windowScene?.session else {
                return nil
            }
            
            var controller = session.userInfo![sceneUserInfoKey] as? PrimarySplitViewController
            if controller == nil {
                controller = PrimarySplitViewController(window: window!)
                session.userInfo![sceneUserInfoKey] = controller
            }
            
            return controller
        } else {
            if _instance == nil {
                _instance = PrimarySplitViewController(window: window!)
            }
            return _instance
        }
    }
    
    private static var _instance: PrimarySplitViewController!
    
    internal var smallScreenSwitcherView: SmallScreenEditorSwitcherView!
    internal var filePickerTabView: SmallScreenEditorTabView!
    
    internal var previewContainer: PreviewContainer!
    
//    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
//        if(UIDevice.current.userInterfaceIdiom == .pad || !UIDevice.current.hasAnEyebrow) {
//            return true
//        }
//        
//        return false
//    }
//    
    func standardInitialize(window: UIWindow) {
        
        // Чуть-чуть поменяешь порядок того, как именно всё инициализируется -
        // приложение полетит далеко и надолго. До того момента, пока не поменяешь
        // обратно. Так что не мудри. Играться можешь разве что с установлением делегата
        // остальное лучше не трогай

        smallScreenSwitcherView = SmallScreenEditorSwitcherView()
        filePickerTabView = SmallScreenEditorTabView(frame: smallScreenSwitcherView.frame, navigationController: FileListNavigationController())
        filePickerTabView.isRemovable = false
        
        presentsWithGesture = false
        
        self.delegate = self
        
        self.previewContainer = PreviewContainer.instance(for: window)
        
        let viewController = UIViewController()
        viewController.view = smallScreenSwitcherView
        viewControllers = [viewController]
    }
    
    internal init(window: UIWindow) {
        super.init(nibName: nil, bundle: nil)
        standardInitialize(window: window)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredDisplayMode = .allVisible
        
        view.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !isLoaded {
            smallScreenSwitcherView.frame = view.bounds
            
            smallScreenSwitcherView.addContainerView(filePickerTabView, animated: false) {
                self.smallScreenSwitcherView.animateIn(animated: false, view: self.filePickerTabView) {
                    if let file = self.fileToOpen {
                        let switcherView = PreviewContainer.activeSwitcherView(for: self.view.window)
                        let editor = Editor.getEditor(configuration: [
                            .openInNewTab: false
                        ], file: file, in: switcherView)

                        editor.openFile(file: file, using: GeneralSourceCodeEditor.forExt(file.url.pathExtension), with: [:], animated: false, in: switcherView)
                    }
                    self.view.isHidden = false
                }
            }
            
            oldIsCollapsed = isCollapsed
            
            if !isCollapsed {
                showDetailViewController(previewContainer, sender: nil)
                isLoaded = true
            }
            if fileToOpen != nil {
                self.preferredDisplayMode = .primaryHidden
            }
        }
    }
    
    var oldIsCollapsed = false
    var firstLayout = true
    
    private func swap(s1: EditorSwitcherView, s2: EditorSwitcherView) {
        
        let presentedView = s1.presentedView
        let presentedViewIndex = presentedView?.index
        
        // let k = s1.doesHavePrimaryTab ? 1 : 0
        
        // Поскольку мы не должны на маленьких экранах видеть "No Editor",
        // мы не должны перемещать туда пустой редактор.
        // Так, как он всегда находится на первом индексе, мы его пропускаем
        // k будет 1 в любом случае.
        
        // Поправка: Нулевой редактор не обязательно пустой,
        // так что делаем каст, проверяющий редактор на пустоту.
        
        let k: Int
        
        if s1.hasPrimaryTab {
            if s1.containerViews.count == 1 && s2.containerViews.isEmpty {
                
                NoEditorPreviewController.present(animated: false, on: s2)
                
                return
            }
            
            if s1.containerViews.count > 1 && s2.containerViews.count > 0 {
                s2.containerViews[0].closeTab(animated: false)
            }
            
            k = 1
            
        } else {
            if let firstContainer = s1.containerViews.first {
                
                let controller = firstContainer.navController.editorViewController
                
                if controller is NoEditorPreviewController {
                    k = 1
                } else {
                    k = 0
                }
                
            } else {
                return
            }
        }
        
        let p = s1.containerViews.count - 1
        
        if p < k {
            return
        }
        
        if s2.isFullScreen && s2.presentedView.index == 0 && s2.hasPrimaryTab {
            s2.animateOut(animated: false, force: true)
        }
        
        s1.animateOut(animated: false)
        
        for _ in k ... p {
            let view = s1.containerViews.remove(at: k)
            
            if s1.presentedView == view {
                if s1.hasPrimaryTab && !s1.containerViews.isEmpty {
                    s1.animateIn(animated: false, view: s1.containerViews.first!)
                }
            }
            view.parentView = s2
            view.layer.anchorPoint = CGPoint(x: 0.5, y: s2.isCompact ? 0 : 0.5)
            
            s2.zoomContainer.addSubview(view)
            s2.containerViews.append(view)
        }
        
        s1.restoreIndexingOrder()
        s2.restoreIndexingOrder()
        
        if !s1.hasPrimaryTab || presentedViewIndex != 0 {
            if presentedView?.parentView.isFullScreen == true {
                presentedView!.parentView.animateOut(animated: false)
            }
            
            if(s2.containerViews[0].navController.editorViewController is NoEditorPreviewController) {
                s2.containerViews[0].closeTab(animated: false, completion: nil)
            }
            
            presentedView?.parentView.animateIn(animated: false, view: presentedView!)
        } else if s1.lastOpenedView != nil {
            let last = s1.lastOpenedView!
            s2.animateIn(animated: false, force: true, view: last)
            s2.layoutSubviews()
        }
        
        if(!s1.isFullScreen && s1.hasPrimaryTab) {
            s1.animateIn(animated: false, force: true, view: s1.containerViews.first!)
        }
    }
    
    override func viewDidLayoutSubviews() {
        
        super.viewDidLayoutSubviews()
        
        if isCollapsed != oldIsCollapsed && isViewLoaded {
            
            let smallScreenSwitcherView = PrimarySplitViewController.instance(for: self.view)!.smallScreenSwitcherView!
            
            if self.isCollapsed {
                swap(
                    s1: self.previewContainer.switcherView,
                    s2: smallScreenSwitcherView
                )
            } else {
                swap(
                    s1: smallScreenSwitcherView,
                    s2: self.previewContainer.switcherView
                )
                self.showDetailViewController(self.previewContainer, sender: nil)
            }
            
            PrimarySplitViewControllerModeButton.updateButtons(in: self.view.window!)
            
        }
        
        oldIsCollapsed = isCollapsed
    }
    
    func openPreferences() {
        let preferencesController = PreferencesLobby()
        let navigationController = ThemeColoredNavigationController(rootViewController: preferencesController)
        navigationController.modalPresentationStyle = .overFullScreen
        self.present(navigationController, animated: true, completion: nil)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return userPreferences.currentTheme.statusBarStyle
    }
}

class PrimarySplitViewControllerModeButton: UIBarButtonItem {
    
    private static var buttons = [PrimarySplitViewControllerModeButton]()
    private var window: UIWindow
    
    static func updateButtons(in window: UIWindow) {
        let splitViewController = PrimarySplitViewController.instance(for: window)!
        let isFullscreen = splitViewController.preferredDisplayMode == .primaryHidden
        
        for button in buttons {
            guard button.window == window else {
                continue
            }
            
            if(splitViewController.isCollapsed) {
                button.image = nil
                button.isEnabled = false
            } else if(isFullscreen) {
                button.image = #imageLiteral(resourceName: "leave-fullscreen.png")
                button.isEnabled = true
            } else {
                button.image = #imageLiteral(resourceName: "enter-fullscreen.png")
                button.isEnabled = true
            }
        }
    }
    
    init(window: UIWindow) {
        self.window = window
        super.init()
        target = self
        action = #selector(toggle)
        
        if(PrimarySplitViewController.instance(for: window).isCollapsed) {
            self.image = nil
            self.isEnabled = false
        } else if(PrimarySplitViewController.instance(for: window)!.preferredDisplayMode == .primaryHidden) {
            self.image = #imageLiteral(resourceName: "leave-fullscreen.png")
            self.isEnabled = true
        } else {
            self.image = #imageLiteral(resourceName: "enter-fullscreen.png")
            self.isEnabled = true
        }
        
        PrimarySplitViewControllerModeButton.buttons.append(self)
    }
    
    @objc func toggle() {
        guard !PrimarySplitViewController.instance(for: self.window).isCollapsed else { return }
        let animationDuration = 0.25
        
        let splitViewController = PrimarySplitViewController.instance(for: self.window)!
        
        let isFullscreen = splitViewController.preferredDisplayMode == .primaryHidden
        
        UIView.animate(withDuration: animationDuration) {
            
            if isFullscreen {
                splitViewController.preferredDisplayMode = .allVisible
            } else {
                splitViewController.preferredDisplayMode = .primaryHidden
            }
            
            PrimarySplitViewControllerModeButton.updateButtons(in: self.window)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let index = PrimarySplitViewControllerModeButton.buttons.firstIndex(of: self) {
            PrimarySplitViewControllerModeButton.buttons.remove(at: index)
        }
    }
}
