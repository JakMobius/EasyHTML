//
//  ExpanderMenuPreferencesMenuCell.swift
//  EasyHTML
//
//  Created by Артем on 25/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit


class AlwaysOpaqueView: UIView {
    override var backgroundColor: UIColor? {
        didSet {
            if backgroundColor?.cgColor.alpha == 0 {
                backgroundColor = oldValue
            }
        }
    }
}

class ExpanderMenuPreferencesMenuCell: BasicCell {
    
    static var textColor = UIColor.white
    var imageContainer = UIImageView()
    var imageBackgroundView = AlwaysOpaqueView()
    
    override func standardInitialise() {
        
        imageBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(imageBackgroundView)
        imageBackgroundView.addSubview(imageContainer)
        
        imageBackgroundView.heightAnchor.constraint(equalToConstant: 30).isActive = true
        imageBackgroundView.widthAnchor.constraint(equalToConstant: 30).isActive = true
        imageBackgroundView.cornerRadius = 5
        imageBackgroundView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        imageBackgroundView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        imageBackgroundView.isOpaque = true
        
        imageContainer.heightAnchor.constraint(equalToConstant: 22).isActive = true
        imageContainer.widthAnchor.constraint(equalToConstant: 22).isActive = true
        imageContainer.centerXAnchor.constraint(equalTo: imageBackgroundView.centerXAnchor).isActive = true
        imageContainer.centerYAnchor.constraint(equalTo: imageBackgroundView.centerYAnchor).isActive = true
        imageContainer.contentMode = .scaleAspectFit
        imageContainer.tintColor = ExpanderMenuPreferencesMenuCell.textColor
        
        label.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 50).isActive = true
        label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        label.heightAnchor.constraint(equalToConstant: 40).isActive = true
        label.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5).isActive = true
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.font = UIFont.systemFont(ofSize: 14)
    }
}
