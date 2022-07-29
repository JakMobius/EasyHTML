//
//  LabelCell.swift
//  EasyHTML
//
//  Created by Артем on 15.03.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class LabelCell: BasicCell {

    var rightLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        rightLabel.translatesAutoresizingMaskIntoConstraints = false
        rightLabel.textAlignment = .right

        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(rightLabel);

        rightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        rightLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        rightLabel.leftAnchor.constraint(equalTo: label.rightAnchor, constant: 10).isActive = true
        rightLabel.heightAnchor.constraint(equalToConstant: 40).isActive = true

        if _testing {
            label.accessibilityIdentifier = "Left"
            rightLabel.accessibilityIdentifier = "Right"
        }

    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
