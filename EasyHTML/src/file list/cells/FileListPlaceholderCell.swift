//
//  FileListPlaceholderCell.swift
//  EasyHTML
//
//  Created by Артем on 10.05.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

internal class FileListPlaceholderCell: UITableViewCell {

    @IBOutlet var imagePlaceholder: UIView!
    @IBOutlet var subtitlePlaceholder: UIView!
    @IBOutlet var titlePlaceholder: UIView!
    @IBOutlet var accessoryInfoButtonPlaceholder: UIView!
    @IBOutlet var accessoryButtonDisclosureButton: UIView!

    private(set) var isLoaded = false

    override func didMoveToSuperview() {
        let backgroundColor = userPreferences.currentTheme.cellColor1

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0

        backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: nil)

        red = (red - 0.5) * 0.8 + 0.5
        green = (green - 0.5) * 0.8 + 0.5
        blue = (blue - 0.5) * 0.8 + 0.5

        let placeholdersColor = UIColor(red: red, green: green, blue: blue, alpha: 1.0)

        imagePlaceholder.backgroundColor = placeholdersColor
        subtitlePlaceholder.backgroundColor = placeholdersColor
        titlePlaceholder.backgroundColor = placeholdersColor
        accessoryInfoButtonPlaceholder.backgroundColor = placeholdersColor
        accessoryButtonDisclosureButton.backgroundColor = placeholdersColor
    }

    private func calculateTransform(scaleX: CGFloat, view: UIView) {
        view.transform = .identity

        let width = view.frame.size.width

        let offset = ((1 - scaleX) * width) / 2

        view.transform = CGAffineTransform(translationX: -offset, y: 0).scaledBy(x: scaleX, y: 1)
    }

    private func randomScale() -> CGFloat {
        CGFloat(arc4random_uniform(5) + 7) / 10
    }

    internal func beginAnimationWithDelay(delay: TimeInterval) {

        if isLoaded {
            return
        }

        isLoaded = true

        alpha = 0

        layoutIfNeeded()

        imagePlaceholder.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        calculateTransform(scaleX: 0.5, view: titlePlaceholder)
        calculateTransform(scaleX: 0.5, view: subtitlePlaceholder)

        UIView.animate(withDuration: 0.2, delay: delay, options: [.curveEaseOut], animations: {
            self.imagePlaceholder.transform = .identity
            self.calculateTransform(scaleX: self.randomScale(), view: self.titlePlaceholder)
            self.calculateTransform(scaleX: self.randomScale(), view: self.subtitlePlaceholder)
            self.alpha = 1.0
        })
    }
}
