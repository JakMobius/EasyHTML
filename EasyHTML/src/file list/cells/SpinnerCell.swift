//
//  SpinnerCell.swift
//  EasyHTML
//
//  Created by Артем on 26/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

class SpinnerCell: UITableViewCell, NotificationHandler {

    var spinner = UIActivityIndicatorView()

    func updateSpinnerStyle() {
        spinner.style = userPreferences.currentTheme.isDark ? .white : .gray
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        updateSpinnerStyle()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(spinner)
        spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        setupThemeChangedNotificationHandling()
    }

    func updateTheme() {

        updateSpinnerStyle()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        clearNotificationHandling()
    }
}
