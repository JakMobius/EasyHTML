//
//  FeedbackPreferencesMenu.swift
//  EasyHTML
//
//  Created by Артем on 01.01.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class FeedbackPreferencesMenu: PreferencesMenu {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = localize("feedback", .preferences)
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        updateStyle()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(indexPath.section == 0) {
            if(indexPath.row == 0) {
                if let url = URL(string: "https://vk.com/id208035941") {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    } else {
                        UIApplication.shared.openURL(url)
                    }
                }
                
            } else if(indexPath.row == 1) {
                if let url = URL(string: "mailto:jakmobius@gmail.com") {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    } else {
                        UIApplication.shared.openURL(url)
                    }
                }
            } // else if...
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if(indexPath.section == 0) {
            cell.accessoryType = .disclosureIndicator
            
            if(indexPath.row == 0) {
                cell.textLabel!.text = localize("vkpage", .preferences);
                cell.imageView?.image = #imageLiteral(resourceName: "vk")
            } else {
                cell.textLabel!.text = localize("bugmail", .preferences)
                cell.imageView?.image = #imageLiteral(resourceName: "mail")
            }
        }
        
        cell.textLabel?.textColor = userPreferences.currentTheme.cellTextColor

        return cell
    }

}
