//
//  ExpanderMenuPreferencesMenu.swift
//  EasyHTML
//
//  Created by Артем on 25/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

class ExpanderMenuPreferencesMenu: AlternatingColorTableView {

    var unusedButtons: [ExpanderButtonItem.ButtonType] = [];
    var shouldRefresh = false {
        didSet {
            if #available(iOS 13.0, *) {
                if UIApplication.shared.openSessions.count > 1 {
                    shouldRefresh = false
                    refresh()
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView = UITableView(frame: tableView.frame, style: .grouped)
        title = localize("helpermenupref", .preferences)
        tableView.register(ExpanderMenuPreferencesMenuCell.self, forCellReuseIdentifier: "cell")
        tableView.register(BasicCell.self, forCellReuseIdentifier: "basic")
        tableView.isEditing = true

        refreshUnusedButtons()

        updateStyle()
    }

    private func refreshUnusedButtons() {
        unusedButtons.removeAll()

        for button in ExpanderButtonItem.ButtonType.allButtons {
            if !userPreferences.expanderButtonsList.contains(where: {
                if case .button(let type) = $0 {
                    return type.type == button
                }
                return false
            }) {
                unusedButtons.append(button);
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0) {
            return localize("helpermenuon", .preferences)
        } else {
            return localize("helpermenumore", .preferences)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        if (section == 0) {
            return userPreferences.expanderButtonsList.count
        } else {
            return unusedButtons.count + 1
        }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if indexPath.section == 0 {
            return .delete
        } else {
            return .insert
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if editingStyle == .delete {
                tableView.beginUpdates()
                let button = userPreferences.expanderButtonsList.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
                if case .button(let type) = button {
                    unusedButtons.append(type.type)
                    tableView.insertRows(at: [
                        IndexPath(row: unusedButtons.count, section: 1)
                    ], with: .fade)
                }
                tableView.endUpdates()
                shouldRefresh = true
            }
        } else if indexPath.section == 1 {
            if editingStyle == .insert {
                if indexPath.row > 0 {
                    tableView.beginUpdates()
                    let button = unusedButtons.remove(at: indexPath.row - 1)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                    userPreferences.expanderButtonsList.append(ExpanderButtonItem.button(.init(type: button)))

                    tableView.insertRows(at: [
                        IndexPath(row: userPreferences.expanderButtonsList.count - 1, section: 0)
                    ], with: .fade)
                    tableView.endUpdates()
                    shouldRefresh = true
                } else {
                    userPreferences.expanderButtonsList.append(ExpanderButtonItem.delimiter)
                    tableView.insertRows(at: [
                        IndexPath(row: userPreferences.expanderButtonsList.count - 1, section: 0)
                    ], with: .fade)
                    shouldRefresh = true
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {

        if sourceIndexPath == destinationIndexPath {
            return
        }

        if sourceIndexPath.section == 0 {

            let element = userPreferences.expanderButtonsList.remove(at: sourceIndexPath.row)

            if destinationIndexPath.section == 0 {
                userPreferences.expanderButtonsList.insert(element, at: destinationIndexPath.row)
            } else {
                if case .button(let type) = element {
                    unusedButtons.insert(type.type, at: destinationIndexPath.row)
                } else {
                    tableView.deleteRows(at: [destinationIndexPath], with: .fade)
                }
            }

            shouldRefresh = true
        }
    }

    var backgroundColor: UIColor = {
        let sourceColor = userPreferences.currentTheme.tabBarSelectedItemColor
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        sourceColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        return UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.95, alpha: 1)

    }()

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.section == 0 {
            let item = userPreferences.expanderButtonsList[indexPath.row]
            switch item {
            case .button(let factory):
                let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ExpanderMenuPreferencesMenuCell

                cell.label.textColor = userPreferences.currentTheme.cellTextColor
                cell.label.text = localize("helpermenuitem\(factory.type.rawValue)", .preferences)
                cell.imageContainer.image = factory.type.image
                cell.imageBackgroundView.backgroundColor = backgroundColor

                return cell
            case .delimiter:
                let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath) as! BasicCell

                cell.label.text = localize("helpermenuitemdelimiter", .preferences)
                cell.label.textColor = userPreferences.currentTheme.secondaryTextColor
                cell.label.font = UIFont.systemFont(ofSize: 14)
                return cell
            }


        } else {
            if (indexPath.row == 0) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath) as! BasicCell

                cell.label.textColor = userPreferences.currentTheme.cellTextColor
                cell.label.text = localize("helpermenuitemdelimiter", .preferences)
                cell.label.font = UIFont.systemFont(ofSize: 14)

                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ExpanderMenuPreferencesMenuCell

                cell.label.textColor = userPreferences.currentTheme.cellTextColor
                let unusedItem = unusedButtons[indexPath.row - 1]
                cell.label.text = localize("helpermenuitem\(unusedItem.rawValue)", .preferences)
                cell.imageContainer.image = unusedItem.image
                cell.imageBackgroundView.backgroundColor = backgroundColor

                return cell
            }
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func refresh() {
        NotificationCenter.default.post(name: .TCUpdateExpanderMenu, object: nil)

        let config: [Int] = userPreferences.expanderButtonsList.map { (item) -> Int in
            if case .button(let factory) = item {
                return factory.type.rawValue
            } else {
                return -1
            }
        }

        Defaults.set(config, forKey: DKey.expanderConfig)
    }

    override func viewDidDisappear(_ animated: Bool) {
        if shouldRefresh {
            refresh()
        }
    }

}
