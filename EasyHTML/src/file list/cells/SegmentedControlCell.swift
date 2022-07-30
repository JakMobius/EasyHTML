//
//  SegmentedControlCell.swift
//  EasyHTML
//
//  Created by Артем on 24/04/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

class SegmentedControlCell: BasicCell {

    var segmentedControl = UISegmentedControl()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        segmentedControl.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(segmentedControl);

        segmentedControl.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 5).isActive = true;
        segmentedControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true;
        segmentedControl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true;
        segmentedControl.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5).isActive = true;
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
