//
//  GitHubViewCodeCell.swift
//  EasyHTML
//
//  Created by Артем on 02/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubRepositoryController {
    class ViewCodeCell: UITableViewCell, NotificationHandler {

        let userNick = UILabel()

        func updateTheme() {

            if userPreferences.currentTheme.isDark {
                userNick.textColor = GitHubUtils.tintDarkColor
            } else {
                userNick.textColor = GitHubUtils.tintLightColor
            }

        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            userNick.translatesAutoresizingMaskIntoConstraints = false
            userNick.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            setupThemeChangedNotificationHandling()
            updateTheme()

            contentView.addSubview(userNick)

            userNick.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
            userNick.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true

            //...
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
}

