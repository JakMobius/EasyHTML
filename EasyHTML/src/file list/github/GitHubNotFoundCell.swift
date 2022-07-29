//
//  GitHubNotFoundCell.swift
//  EasyHTML
//
//  Created by Артем on 28/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit


extension GitHubLobby {
    class NotFoundCell: UITableViewCell, NotificationHandler {
        
        let label = UILabel()
        
        func updateTheme() {
            
            label.textColor = userPreferences.currentTheme.secondaryTextColor
        }
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 12, weight: .light)
            
            setupThemeChangedNotificationHandling()
            updateTheme()
            
            contentView.addSubview(label)
            
            label.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
            label.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
            
            //...
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
}


