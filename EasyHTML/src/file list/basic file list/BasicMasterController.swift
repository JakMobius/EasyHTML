//
//  BasicMasterController.swift
//  EasyHTML
//
//  Created by Артем on 10/09/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

internal class BasicMasterController: AlternatingColorTableView {
    
    var prefButton: UIBarButtonItem!
    
    var errorLabel: UILabel!
    
    override func updateTheme() {
        super.updateTheme()
        
        if errorLabel != nil {
            errorLabel.textColor = userPreferences.currentTheme.secondaryTextColor
        }	
    }
    func updateToolBar() {
        prefButton.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
    }
    
    func removeErrorLabel() {
        if errorLabel != nil {
            errorLabel.removeFromSuperview()
            errorLabel = nil
        }
    }
    
    func showErrorLabel(text: String!) {
        var text = text
        
        if text == nil {
            text = localize("unknownerror")
        }
        
        errorLabel = UILabel()
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        tableView.addSubview(errorLabel)
        errorLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 20).isActive = true
        errorLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor).isActive = true
        errorLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 20).isActive = true
        errorLabel.font = UIFont.systemFont(ofSize: 14)
        errorLabel.textColor = userPreferences.currentTheme.secondaryTextColor
        errorLabel.text = text
        errorLabel.numberOfLines = -1
        errorLabel.textAlignment = .center
        errorLabel.widthAnchor.constraint(lessThanOrEqualTo: self.view.widthAnchor, constant: -20).isActive = true
    }
    
    @objc internal func openPreferences(_ sender: UIButton)
    {
        if PreferencesLobby.instance != nil {
            return
        }
        
        PrimarySplitViewController.instance(for: self.view).openPreferences()
    }
    
    internal func setupToolBar() {
        
        let image = #imageLiteral(resourceName: "pref.png").withRenderingMode(.alwaysTemplate)
        prefButton =  UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(openPreferences(_:)))
        
        prefButton.width = 20
        prefButton.isEnabled = PreferencesLobby.instance == nil
        
        setToolbarItems([
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            prefButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            ], animated: false)
        
        updateToolBar()
        
        NotificationCenter.default.addObserver(self, selector: #selector(disableToolbarButton), name: .TCPreferencesOpened, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enableToolbarButton), name: .TCPreferencesClosed, object: nil)
    }
    
    @objc func disableToolbarButton() {
        prefButton.isEnabled = false
    }
    
    @objc func enableToolbarButton() {
        prefButton.isEnabled = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
