//
//  AboutPreferencesMenu.swift
//  EasyHTML
//
//  Created by Артем on 22.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

class AboutPreferencesMenu: PreferencesMenu {

    private let statDescs = [
        "stat_symbolswritten",
        "stat_filescreated",
        "stat_filesdeleted",
        "stat_filesopened",
        "stat_folderscreated",
        "stat_foldersdeleted",
        "stat_installdate",
        "stat_installversion"
    ]

    private static let dateFormatter = { () -> DateFormatter in
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "dd MMMM yyyy hh:mm:ss"

        return dateFormatter
    }()

    private let statValues = [
        String(userPreferences.statistics.symbolsWrittenTotal),
        String(userPreferences.statistics.filesCreated),
        String(userPreferences.statistics.filesDeleted),
        String(userPreferences.statistics.filesOpened),
        String(userPreferences.statistics.foldersCreated),
        String(userPreferences.statistics.foldersDeleted),
        AboutPreferencesMenu.dateFormatter.string(for: userPreferences.statistics.installDate
        ),
        userPreferences.statistics.installVersion
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = localize("aboutprogram", .preferences)

        tableView.register(LabelCell.self, forCellReuseIdentifier: "cell")

        updateStyle()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        false
    }

    override func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        false
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? nil : localize("statistics", .preferences)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : 8
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return Bundle.main.loadNibNamed("AboutCell", owner: self, options: nil)?.first as! UITableViewCell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! LabelCell

            let font = UIFont.systemFont(ofSize: 13)

            var value = statValues[indexPath.row]

            if indexPath.row == 7 && value == "1.3.1" {
                value = localize("stat_earlyversion", .preferences)
            } else {
                value = statValues[indexPath.row]
            }

            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            cell.rightLabel.textColor = userPreferences.currentTheme.cellTextColor

            cell.label.text = localize(statDescs[indexPath.row], .preferences)
            cell.rightLabel.text = value

            cell.label.font = font
            cell.rightLabel.font = font

            return cell
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
    }
}
