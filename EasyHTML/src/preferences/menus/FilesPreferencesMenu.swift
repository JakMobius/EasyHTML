//
//  FilesPreferencesMenu.swift
//  EasyHTML
//
//  Created by Артем on 20.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

class FilesPreferencesMenu: PreferencesMenu {
    
    private static var names = [
        localize("byeditingdate", .preferences),
        localize("bycreationdate", .preferences),
        localize("byname", .preferences),
        localize("bytype", .preferences),
        localize("nosorting", .preferences)
    ]
    
    private static var descriptions = [
        localize("byeditingdatedesc", .preferences),
        localize("bycreationdatedesc", .preferences),
        localize("bynamedesc", .preferences),
        localize("bytypedesc", .preferences),
        localize("nosortingdesc", .preferences)
    ]
    
    var checkedIndex = userPreferences.sortingType.rawValue
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard checkedIndex != indexPath.row else { return }
        
        checkedIndex = indexPath.row
        
        updateDescription()
        
        if UIDevice.current.produceSimpleHapticFeedback() {
            if #available(iOS 10.0, *) {
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()
            }
        }
        
        userPreferences.sortingType = SortingType(rawValue: checkedIndex)!
        Defaults.set(checkedIndex, forKey: DKey.sortingType)
        
        FileBrowser.fileListUpdatedAt(url: nil)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 0 ? FilesPreferencesMenu.descriptions[checkedIndex] : localize("sortdescription", .preferences)
    }
    
    private func updateDescription() {
        tableView.reloadData()
    }
    
    private let font = UIFont.systemFont(ofSize: 14)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        title = localize("files", .preferences)
        updateDescription()
        
        updateStyle()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? localize("sortingtype", .preferences) : ""
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 5 : 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        
        if(indexPath.row == checkedIndex) {
            checkedIndex = indexPath.row
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        cell.textLabel!.text = FilesPreferencesMenu.names[indexPath.row]
        cell.textLabel!.textColor = userPreferences.currentTheme.cellTextColor
        cell.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
        cell.textLabel!.font = font
        
        return cell
    }
 
}
