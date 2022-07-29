//
//  SyntaxHighlightingPicker.swift
//  EasyHTML
//
//  Created by Артем on 25.06.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

protocol SyntaxHighlightingPickerDelegate: class {
    func syntaxHighlightingPicker(_ picker: SyntaxHighlightingPicker, didSelect type: SyntaxHighlightScheme.Mode)
}

class SyntaxHighlightingPicker: AlternatingColorTableView {
    
    weak var delegate: SyntaxHighlightingPickerDelegate! = nil
    
    override func viewDidLoad() {
        title = localize("selecthighlightingmode", .preferences)
        
        tableView = UITableView(frame: tableView.frame, style: .grouped)
        tableView.register(BasicCell.self, forCellReuseIdentifier: "cell")
        
        if selectedType != nil {
            selectedIndex = SyntaxHighlightScheme.Mode.allModes.firstIndex { $0.cmMimeType == selectedType.cmMimeType }
        }
        
        updateStyle()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return SyntaxHighlightScheme.Mode.allModes.count
    }
    
    var selectedType: SyntaxHighlightScheme.Mode! = nil
    private var selectedIndex: Int! = nil
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let oldIndex = selectedIndex
        
        selectedIndex = indexPath.row
        selectedType = SyntaxHighlightScheme.Mode.allModes[indexPath.row]
        
        if oldIndex != nil {
            tableView.reloadRows(at: [IndexPath(row: oldIndex!, section: 0)], with: .none)
        }
        
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        delegate?.syntaxHighlightingPicker(self, didSelect: selectedType)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! BasicCell
        
        let type = SyntaxHighlightScheme.Mode.allModes[indexPath.row]
        
        cell.label.text = type.description
        cell.label.textColor = userPreferences.currentTheme.cellTextColor
        cell.label.font = .systemFont(ofSize: 13)
        cell.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
        
        if selectedIndex == indexPath.row {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
}
