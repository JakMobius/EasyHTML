//
//  EditorTitleButtonView.swift
//  EasyHTML
//
//  Created by Артем on 26/10/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class EditorTitleButtonView: UIView, NotificationHandler {

    let image: UIImageView = {
        let image = UIImageView()
        image.image = #imageLiteral(resourceName: "expand").withRenderingMode(.alwaysTemplate)
        image.tintColor = userPreferences.currentTheme.navigationTitle
        image.contentMode = .scaleAspectFit
        return image
    }()

    let button: UIButton = {
        let button = UIButton()
        button.titleLabel!.textColor = userPreferences.currentTheme.navigationTitle
        button.titleLabel!.font = UIFont.boldSystemFont(ofSize: 17)
        return button
    }()

    func standardInitialise() {
        addSubview(button)
        addSubview(image)

        setupThemeChangedNotificationHandling()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        standardInitialise()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        standardInitialise()
    }

    private(set) var buttonIsBottom = false

    func toggleArrowAnimated() {
        UIView.animate(withDuration: 0.4) {
            if (self.buttonIsBottom) {
                self.image.transform = .identity
            } else {
                self.image.transform = CGAffineTransform(rotationAngle: .pi)
            }
            self.buttonIsBottom = !self.buttonIsBottom
        }
    }

    func updateTheme() {

        button.titleLabel!.textColor = userPreferences.currentTheme.navigationTitle
        image.tintColor = userPreferences.currentTheme.navigationTitle
    }

    func updateSize() {

        let imageSize: CGFloat = 12
        let halfImageSize: CGFloat = 6
        let margin: CGFloat = 5

        let superviewHeight = superview?.frame.height ?? 44

        button.titleLabel!.sizeToFit()
        button.titleLabel!.frame.size.height = superviewHeight
        button.frame = button.titleLabel!.bounds
        frame.size.width = button.titleLabel!.frame.width + imageSize + margin
        frame.size.height = button.titleLabel!.frame.height

        image.frame.origin.y = frame.size.height / 2 - halfImageSize
        image.frame.origin.x = frame.width - imageSize
        image.frame.size = CGSize(width: imageSize, height: imageSize)
    }

    deinit {
        clearNotificationHandling()
    }
}
