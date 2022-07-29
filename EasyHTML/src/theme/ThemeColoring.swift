//
//  StandartNavigationController.swift
//  EasyHTML
//
//  Created by Артем on 11.10.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import Foundation
import UIKit

extension NotificationCenter {
    
    func setupFileListUpdatedNotificationHandling(_ target: Any, selector: Selector) {
        addObserver(target, selector: selector, name: .TCFileListUpdated, object: nil)
    }
    
    func setupRotationNotificationHandling(_ target: Any, selector: Selector) {
        addObserver(target, selector: selector, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    func setupKeyboardDidShowNotificationHandling(_ target: Any, selector: Selector) {
        addObserver(target, selector: selector, name: UIResponder.keyboardDidShowNotification, object: nil)
    }
    
    func setupKeyboardWillShowNotificationHandling(_ target: Any, selector: Selector) {
        addObserver(target, selector: selector, name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    func setupKeyboardDidHideNotificationHandling(_ target: Any, selector: Selector) {
        addObserver(target, selector: selector, name: UIResponder.keyboardDidHideNotification, object: nil)
    }
    
    func setupKeyboardWillHideNotificationHandling(_ target: Any, selector: Selector) {
        addObserver(target, selector: selector, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func setupKeyboardWillChangeFrameNotificationHandling(_ target: Any, selector: Selector) {
        addObserver(target, selector: selector, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    func setupKeyboardDidChangeFrameNotificationHandling(_ target: Any, selector: Selector) {
        addObserver(target, selector: selector, name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
    }
    
    func setupLanguageChangedNotificationHandling(_ target: Any, selector: Selector) {
        addObserver(target, selector: selector, name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
    }
}

class DeinitObserver : NSObject {
    private var block: () -> ();
    init(_ block: @escaping () -> ()) {
        self.block = block;
    }
    
    deinit {
        block();
    }
}

@objc protocol NotificationHelper: class {
    @objc optional func deviceRotated()
    @objc optional func updateTheme()
    @objc optional func fileListUpdated(sender: NSNotification)
    @objc optional func keyboardWillShow(sender: NSNotification)
    @objc optional func keyboardDidShow(sender: NSNotification)
    @objc optional func keyboardWillHide(sender: NSNotification)
    @objc optional func keyboardDidHide(sender: NSNotification)
    @objc optional func keyboardWillChangeFrame(sender: NSNotification)
    @objc optional func keyboardDidChangeFrame(sender: NSNotification)
    @objc optional func languageChanged()
}

/// Протокол, позволяющий настраивать обработку базовых системных событий

protocol NotificationHandler: NotificationHelper, Equatable {
    func setupThemeChangedNotificationHandling()
    func setupFileListUpdatedNotificationHandling()
    func setupRotationNotificationHandling()
    func setupKeyboardDidShowNotificationHandling()
    func setupKeyboardWillShowNotificationHandling()
    func setupKeyboardDidHideNotificationHandling()
    func setupKeyboardWillHideNotificationHandling()
    func setupKeyboardWillChangeFrameNotificationHandling()
    func setupKeyboardDidChangeFrameNotificationHandling()
    func setupLanguageChangedNotificationHandling()
    
    func clearNotificationHandling()
}

extension NotificationHandler {
    
    func setupThemeChangedNotificationHandling() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateTheme), name: .TCThemeChanged, object: nil)
    }
    
    func setupFileListUpdatedNotificationHandling() {
        NotificationCenter.default.setupFileListUpdatedNotificationHandling(self, selector: #selector(fileListUpdated))
    }
    
    func setupRotationNotificationHandling() {
        NotificationCenter.default.setupRotationNotificationHandling(self, selector: #selector(deviceRotated))
    }
    
    func setupKeyboardDidShowNotificationHandling() {
        NotificationCenter.default.setupKeyboardDidShowNotificationHandling(self, selector: #selector(keyboardDidShow))
    }
    
    func setupKeyboardWillShowNotificationHandling() {
        NotificationCenter.default.setupKeyboardWillShowNotificationHandling(self, selector: #selector(keyboardWillShow))
    }
    
    func setupKeyboardDidHideNotificationHandling() {
        NotificationCenter.default.setupKeyboardDidHideNotificationHandling(self, selector: #selector(keyboardDidHide))
    }
    
    func setupKeyboardWillHideNotificationHandling() {
        NotificationCenter.default.setupKeyboardWillHideNotificationHandling(self, selector: #selector(keyboardWillHide))
    }
    
    func setupKeyboardWillChangeFrameNotificationHandling() {
        NotificationCenter.default.setupKeyboardWillChangeFrameNotificationHandling(self, selector: #selector(keyboardWillChangeFrame))
    }
    
    func setupKeyboardDidChangeFrameNotificationHandling() {
        NotificationCenter.default.setupKeyboardDidChangeFrameNotificationHandling(self, selector: #selector(keyboardDidChangeFrame))
    }
    
    func setupLanguageChangedNotificationHandling() {
        NotificationCenter.default.setupLanguageChangedNotificationHandling(self, selector: #selector(languageChanged))
    }
    
    func clearNotificationHandling() {
        NotificationCenter.default.removeObserver(self)
    }
}

extension UIView {
    var globalPoint :CGPoint? {
        return self.superview?.convert(self.frame.origin, to: nil)
    }
    
    var globalFrame :CGRect? {
        return self.superview?.convert(self.frame, to: nil)
    }
}

internal class AlternatingColorTableView : UITableViewController, NotificationHandler {
    
    internal func updateCellColors(delay: Double = 0.2)
    {
        guard let tableView = self.tableView else {
            return
        }
        
        func updateColors() {
            tableView.reloadData()
            /*for cell in tableView.visibleCells {
                guard let indexPath = tableView.indexPath(for: cell) else { return }
                tableView.delegate?.tableView?(tableView, willDisplay: cell, forRowAt: indexPath)
            }*/
        }
        
        let time = DispatchTime.now() + delay
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: time, execute: {
                updateColors()
            })
        } else {
            updateColors()
        }
    }
    
    override internal func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let color = indexPath.row % 2 == 1 ? userPreferences.currentTheme.cellColor1 : userPreferences.currentTheme.cellColor2
        
        cell.backgroundColor = color
    }
    
    internal func updateStyle() {
        tableView.backgroundView = nil
        tableView.backgroundColor = userPreferences.currentTheme.background
        tableView.separatorColor = userPreferences.currentTheme.tableViewDelimiterColor
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 4)
        tableView.indicatorStyle = userPreferences.currentTheme.isDark ? .white : .black
    }
    
    func updateTheme() {
        
        tableView.reloadData()
        tableView.separatorColor = userPreferences.currentTheme.tableViewDelimiterColor
        
        for cell in tableView.visibleCells {
            cell.updateColors()
        }
    }
    
    private var footerViewActivityIndicator: UIActivityIndicatorView!
    internal var shouldShowActivityIndicatorAtBottom: Bool {
        get {
            return footerViewActivityIndicator != nil
        }
        set {
            if newValue == (footerViewActivityIndicator != nil) {
                return
            }
            
            footerView?.textLabel?.isHidden = newValue
            
            if newValue {
                footerViewActivityIndicator = UIActivityIndicatorView()
                
                if userPreferences.currentTheme.isDark {
                    footerViewActivityIndicator.style = .white
                } else {
                    footerViewActivityIndicator.style = .gray
                }
                
                footerViewActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
                
                if let footerView = self.footerView {
                    addActivityIndicatorToFooterView(footerView: footerView)
                }
                
                footerViewActivityIndicator.startAnimating()
                
                tableView.contentOffset.y += 1
                tableView.contentOffset.y -= 1
            } else {
                footerViewActivityIndicator?.removeFromSuperview()
                footerViewActivityIndicator = nil
            }
        }
    }
    
    private func addActivityIndicatorToFooterView(footerView: UIView) {
        guard shouldShowActivityIndicatorAtBottom && footerViewActivityIndicator!.superview == nil else {return}
        
        footerView.addSubview(footerViewActivityIndicator)
        
        footerView.centerXAnchor.constraint(equalTo: footerViewActivityIndicator.centerXAnchor).isActive = true
        footerView.centerYAnchor.constraint(equalTo: footerViewActivityIndicator.centerYAnchor, constant: 0).isActive = true
    }
    
    private var footerView: UITableViewHeaderFooterView!
    
    internal override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == numberOfSections(in: tableView) - 1 {
            if let footerView = footerView {
                return footerView
            }
            
            let view = UITableViewHeaderFooterView()
            
            footerView = view
            
            view.textLabel?.isHidden = shouldShowActivityIndicatorAtBottom
            
            if shouldShowActivityIndicatorAtBottom {
                addActivityIndicatorToFooterView(footerView: view)
            }
            
            return view
        }
        
        return nil
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.text = tableView.dataSource?.tableView?(tableView, titleForFooterInSection: section)
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let activityIndicator = footerViewActivityIndicator, let footerView = footerView {
            let scrollTop = scrollView.contentOffset.y
            let scrollHeight = scrollView.contentSize.height - scrollView.frame.height
            let scrollBottom = scrollHeight - scrollTop
            
            let footerViewPosition = tableView.frame.height - footerView.frame.maxY + scrollTop
            
            activityIndicator.transform.ty = scrollBottom + footerViewPosition
        }
    }
}

extension UITableViewCell {
    
    open func updateColors() {
        let bg = UIView(frame: bounds)
        bg.backgroundColor = userPreferences.currentTheme.cellSelectedColor
        selectedBackgroundView = bg
    }
    
    override open func didMoveToWindow() {
        updateColors()
    }
}

internal class ThemeColoredNavigationController: UINavigationController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return userPreferences.currentTheme.statusBarStyle
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: ThemedNavigationBar.self, toolbarClass: toolbarClass)
    }
    
    init() {
        super.init(navigationBarClass: ThemedNavigationBar.self, toolbarClass: nil)
    }
    
    override init(rootViewController: UIViewController) {
        super.init(navigationBarClass: ThemedNavigationBar.self, toolbarClass: nil)
        self.viewControllers = [rootViewController]
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
