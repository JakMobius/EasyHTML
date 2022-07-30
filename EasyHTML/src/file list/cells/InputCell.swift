//
//  InputCell.swift
//  EasyHTML
//
//  Created by Артем on 16.05.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class InputCell: BasicCell {
    var input = UITextField()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super.init(style: style, reuseIdentifier: reuseIdentifier)


        input.translatesAutoresizingMaskIntoConstraints = false
        input.textAlignment = .right

        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(input);

        input.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        input.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        input.leftAnchor.constraint(equalTo: label.rightAnchor, constant: 10).isActive = true
        input.heightAnchor.constraint(equalToConstant: 40).isActive = true

        updateKeyboardAppearance()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    final func updateKeyboardAppearance() {
        input.keyboardAppearance = userPreferences.currentTheme.isDark ? .dark : .light
    }
}
