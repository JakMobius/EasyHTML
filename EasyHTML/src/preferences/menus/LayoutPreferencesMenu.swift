//
//  LayoutPreferencesMenu.swift
//  EasyHTML
//
//  Created by Артем on 20.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

class LayoutPreferencesMenu: PreferencesMenu {
    
    var selectedIndex = userPreferences.currentTheme.id
    
    var switcherCell: SwitchCell?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = localize("layout", .preferences)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(SwitchCell.self, forCellReuseIdentifier: "switch")
        
        updateStyle()
    }

    override func tableView(  _ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(indexPath.section == 0) {
            if UIDevice.current.produceSimpleHapticFeedback() {
                if #available(iOS 10.0, *) {
                    let generator = UISelectionFeedbackGenerator()
                    generator.prepare()
                    generator.selectionChanged()
                }
            }
            
            if selectedIndex == indexPath.row {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            
            if #available(iOS 13.0, *) {
                let scenes = UIApplication.shared.connectedScenes
                
                UIView.transition(with: view.window!, duration: 0.25, options: [.transitionCrossDissolve], animations: {
                    userPreferences.currentTheme = Theme.themes[indexPath.row]
                    
                    userPreferences.applyTheme()
                    self.updateStyle()
                    tableView.reloadData()
                    self.updateCellColors()
                    
                }, completion: nil)
                
                for scene in scenes {
                    for window in (scene as! UIWindowScene).windows {
                        
                        let transition = CATransition()
                        transition.duration = 0.3
                        transition.type = CATransitionType.fade
                        window.layer.add(transition, forKey: nil)
                    
                        for view in window.subviews {
                            view.removeFromSuperview()
                            window.addSubview(view)
                        }
                    }
                }
                
                NotificationCenter.default.post(name: .TCThemeChanged, object: nil)
            } else {
                let window = view.window!
                DispatchQueue.main.async {
                    UIView.transition(with: window, duration: 0.25, options: [.transitionCrossDissolve], animations: {
                        userPreferences.currentTheme = Theme.themes[indexPath.row]
                        
                        userPreferences.applyTheme()
                        self.updateStyle()
                        tableView.reloadData()
                        self.updateCellColors()
                        
                        for view in window.subviews {
                            view.removeFromSuperview()
                            window.addSubview(view)
                        }
                        
                    }, completion: {
                        _ in
                        NotificationCenter.default.post(name: .TCThemeChanged, object: nil, userInfo: ["window" : window])
                        NotificationCenter.default.post(name: .TCThemeChanged, object: nil)
                    })
                }
            }
            
            
            
            
            
            selectedIndex = indexPath.row
            
            Defaults.set(selectedIndex, forKey: DKey.theme)
            
        } else if(indexPath.section == 1) {
            if let cell = tableView.cellForRow(at: indexPath) as? SwitchCell {
                cell.switcher.setOn(!cell.switcher.isOn, animated: true)
                if(indexPath.row == 0) {
                    userPreferences.hapticFeedbackEnabled = cell.switcher.isOn
                    Defaults.set(userPreferences.hapticFeedbackEnabled, forKey: DKey.hapticFeedbackEnabled)
                }
            }
            
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? localize("themesectiontitle", .preferences) : section == 1 ? nil : localize("hapticfeedbackoptions", .preferences)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 0 ? localize("usageofblacktheme", .preferences) : nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return UIDevice.current.isHapticFeedbackSupported ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? Theme.themes.count : 1
    }
    
    @objc func hapticFeedbackAction(_ sender: UISwitch) {
        userPreferences.hapticFeedbackEnabled = sender.isOn
        Defaults.set(userPreferences.hapticFeedbackEnabled, forKey: DKey.hapticFeedbackEnabled)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if(indexPath.section == 0) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            
            if(indexPath.row == selectedIndex) {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            
            cell.textLabel!.text = localize("theme\(indexPath.row)", .preferences)
            cell.textLabel!.font = UIFont.systemFont(ofSize: 14)
            cell.textLabel!.textColor = userPreferences.currentTheme.cellTextColor
            cell.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
            cell.selectedBackgroundView?.backgroundColor = userPreferences.currentTheme.cellSelectedColor
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch") as! SwitchCell
            cell.switcher.isOn = userPreferences.hapticFeedbackEnabled
            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            cell.label.text = localize("hapticfeedback", .preferences)
            cell.label.font = UIFont.systemFont(ofSize: 14)
            cell.selectedBackgroundView?.backgroundColor = userPreferences.currentTheme.cellSelectedColor
            
            if cell.switcher.actions(forTarget: self, forControlEvent: .valueChanged)?.isEmpty ?? true {
                cell.switcher.addTarget(self, action: #selector(hapticFeedbackAction(_:)), for: .valueChanged)
            }
            
            return cell
        }
        
    }
}
