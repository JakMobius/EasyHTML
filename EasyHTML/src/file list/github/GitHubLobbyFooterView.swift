//
//  GitHubLobbyFooterView.swift
//  EasyHTML
//
//  Created by Артем on 26/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubLobby {
    class FooterView: UITableViewHeaderFooterView {
        
        var label = UILabel()
        
        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            
            label.font = UIFont.systemFont(ofSize: 18)
            label.text = localize("norecentitems", .github)
            label.textColor = .gray
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = -1
            label.textAlignment = .center
            
            addSubview(label)
            
            label.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
            label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            label.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 20).isActive = true
            label.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -20).isActive = true
            
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
}
