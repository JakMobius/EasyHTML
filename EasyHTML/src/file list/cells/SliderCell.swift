//
//  SwitchCell.swift
//  EasyHTML
//
//  Created by Артем on 20.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

class SliderCell: UITableViewCell {

    var slider = UISlider()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        slider.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(slider);

        slider.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        slider.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -15).isActive = true
        slider.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

class LabeledSliderCell: UITableViewCell {

    var slider = UISlider()
    var minLabel = UILabel()
    var maxLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(minLabel)
        contentView.addSubview(maxLabel)
        contentView.addSubview(slider)

        minLabel.translatesAutoresizingMaskIntoConstraints = false
        maxLabel.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false

        minLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        minLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        maxLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        maxLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true

        slider.leftAnchor.constraint(equalTo: minLabel.rightAnchor, constant: 10).isActive = true
        slider.rightAnchor.constraint(equalTo: maxLabel.leftAnchor, constant: -10).isActive = true
        slider.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true

    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

}
