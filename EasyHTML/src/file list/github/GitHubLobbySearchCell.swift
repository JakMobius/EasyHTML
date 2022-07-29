//
//  GitHubLobbySearchCell.swift
//  EasyHTML
//
//  Created by Артем on 26/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubLobby {
    class SearchCell: UITableViewCell, UITextFieldDelegate, NotificationHandler {
        
        var field = UITextField()
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            
            field.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(field);
            
            field.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 7).isActive = true
            field.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -7).isActive = true
            field.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
            field.heightAnchor.constraint(equalToConstant: 30).isActive = true
            
            updateTheme()
            
            field.textColor = userPreferences.currentTheme.cellTextColor
            field.setLeftPaddingPoints(6.0)
            field.returnKeyType = .done
            field.font = UIFont.systemFont(ofSize: 14)
            
            if #available(iOS 11.0, *) {
                field.smartDashesType = .no
                field.smartQuotesType = .no
                field.smartInsertDeleteType = .no
            }
            
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            
            field.delegate = self
            
            setupThemeChangedNotificationHandling()
        }
        
        func updateTheme() {
            
            field.attributedPlaceholder = NSAttributedString(string: localize("searchrepo", .github), attributes: [NSAttributedString.Key.foregroundColor: userPreferences.currentTheme.secondaryTextColor])
            field.textColor = userPreferences.currentTheme.cellTextColor
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return false
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
        
        deinit {
            clearNotificationHandling()
        }
    }
}
