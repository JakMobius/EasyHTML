//
//  TabTitleContainerView.swift
//  EasyHTML
//
//  Created by Артем on 14/10/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class TabTitleContainerView: UIView {
    var closeButton: UIImageView = UIImageView(image: UIImage(named: "x-close")?.withRenderingMode(.alwaysTemplate))

    var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 22)
        label.textAlignment = .center
        return label
    }()

    private(set) var isCompact = false

    func becomeCompact() {
        if isCompact {
            return
        }

        isCompact = true

        titleLabel.frame.size.height = 32
        titleLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        updateButtonFrame()
    }

    func becomeRegular() {
        if !isCompact {
            return
        }

        isCompact = false

        titleLabel.frame.size.height = bounds.height
        titleLabel.transform = .identity

        updateButtonFrame()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = userPreferences.currentTheme.themeColor
        addSubview(titleLabel)

        addSubview(closeButton)
        addSubview(titleLabel)

        titleLabel.textColor = userPreferences.currentTheme.navigationTitle

        updateTheme()

        NotificationCenter.default.addObserver(self, selector: #selector(updateTheme), name: .TCThemeChanged, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    @objc func updateTheme() {

        titleLabel.textColor = userPreferences.currentTheme.navigationTitle
        backgroundColor = userPreferences.currentTheme.themeColor
        closeButton.tintColor = userPreferences.currentTheme.navigationTitle
    }

    private let maxButtonSize: CGFloat = 20
    private var padding: CGFloat = 9

    private func updateButtonFrame() {
        let height = bounds.height

        var buttonSize = isCompact ? 14 : height - (padding * 2)
        var padding = padding

        if buttonSize > maxButtonSize && !isCompact {
            buttonSize = maxButtonSize
            padding = (height - buttonSize) / 2
        }

        closeButton.frame = CGRect(
                x: padding,
                y: padding,
                width: buttonSize,
                height: buttonSize
        )
    }

    override func layoutSubviews() {
        let height = bounds.height

        updateButtonFrame()

        let labelPadding = closeButton.frame.width + closeButton.frame.origin.x * 2

        titleLabel.frame = CGRect(
                x: labelPadding,
                y: 0,
                width: bounds.width - labelPadding * 2,
                height: isCompact ? 32 : height
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
