//
//  BasicCell.swift
//  EasyHTML
//
//  Created by Артем on 15.03.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class BasicCell: UITableViewCell {

    var label = UILabel()
    
    func standardInitialise() {
        label.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20).isActive = true
        label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        label.heightAnchor.constraint(equalToConstant: 40).isActive = true
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(label);
        
        standardInitialise()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
