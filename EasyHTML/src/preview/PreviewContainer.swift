//
//  PreviewContainer.swift
//  EasyHTML
//
//  Created by Артем on 24.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

class PreviewNavigationController: TabNavigationController {
    internal var editor: Editor!
    
    private func getCustomBackButton() -> UIButton {
        
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "back")?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.addTarget(self, action: #selector(back), for: .touchUpInside)

        button.imageEdgeInsets = UIEdgeInsets(top: 11, left: 0, bottom: 11, right: 0)
        
        button.imageView!.contentMode = .scaleAspectFit
        
        return button
    }
    
    @objc func back() {
        goBack()
    }
    
    private lazy var backButton = getCustomBackButton()
    
    internal func updateNavigationBar() {
        
        backButton.imageView!.tintColor = userPreferences.currentTheme.buttonColor
        
        let barButton = UIBarButtonItem(title: "  ", style: .plain, target: nil, action: nil)
        navigationBar.topItem?.leftBarButtonItems = [barButton]
        
        backButton.superview?.bringSubviewToFront(backButton)
    }
    
    override func viewDidLayoutSubviews() {
        updateNavigationBar()
        super.viewDidLayoutSubviews()
    }
    
    internal override func viewDidLoad() {
        super.viewDidLoad()
        updateTitle()
        
        navigationBar.addSubview(backButton)
        
        let safeAreaAnchor: NSLayoutXAxisAnchor
        
        if #available(iOS 11.0, *) {
            safeAreaAnchor = navigationBar.safeAreaLayoutGuide.leftAnchor
        } else {
            safeAreaAnchor = navigationBar.leftAnchor
        }
        
        backButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        backButton.leftAnchor.constraint(equalTo: safeAreaAnchor, constant: -15).isActive = true
        backButton.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor).isActive = true
        backButton.widthAnchor.constraint(equalToConstant: 65).isActive = true
        
    }
    
    override func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        super.navigationController(navigationController, didShow: viewController
            , animated: animated)
        
        updateNavigationBar()
    }
}

class PreviewContainer: UIViewController {

    /**
     * Возвращает текущий активный  `EditorSwitcherView`.
     * - parameter view: Любой `UIView`, находящийся в `UIWindow`. может быть `nil`, если версия iOS гарантировано ниже 13.0
     */
    
    static func activeSwitcherView(for view: UIView! = nil) -> EditorSwitcherView {
        let inst = PrimarySplitViewController.instance(for: view)!
        if inst.isCollapsed {
            return inst.smallScreenSwitcherView
        } else {
            return PreviewContainer.instance(for: view)!.switcherView
        }
    }
    
    static var sceneUserInfoKey: String = "P"
    
    static func instance(for view: UIView) -> PreviewContainer! {
        if #available(iOS 13.0, *) {
            var window: UIWindow?
            
            if let view = view as? UIWindow {
                window = view
            } else {
                window = view.window
            }
            
            guard let session = window?.windowScene?.session else {
                return nil
            }
            
            var controller = session.userInfo![sceneUserInfoKey] as? PreviewContainer
            
            if controller == nil {
                controller = PreviewContainer()
                session.userInfo![sceneUserInfoKey] = controller
            }
            
            return controller
        } else {
            if uniqueInstance == nil {
                uniqueInstance = PreviewContainer()
            }
            return uniqueInstance
        }
    }
    
    static var uniqueInstance: PreviewContainer!
    
    internal var switcherView: EditorSwitcherView! = nil
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        let editorSwitcherView = EditorSwitcherView(frame: view.bounds)
        switcherView = editorSwitcherView
        view = editorSwitcherView
        view.backgroundColor = .darkGray
        
        let largeScreenSwitcherView = switcherView!
        NoEditorPreviewController.present(animated: false, on: largeScreenSwitcherView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
