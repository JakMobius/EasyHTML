//
//  SwitchCell.swift
//  EasyHTML
//
//  Created by Артем on 20.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

class SwitchCell: BasicCell {
    
    var switcher = UISwitch()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        switcher.translatesAutoresizingMaskIntoConstraints = false
        
        self.contentView.addSubview(switcher);
        
        switcher.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        switcher.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -15).isActive = true
        label.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -75).isActive = true
        

    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
