//
//  ExpanderView.swift
//  EasyHTML
//
//  Created by Артем on 03/10/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

protocol ExpanderViewDelegate: AnyObject {
    func expanderViewButtonTapped(type: ExpanderButtonItem.ButtonType, repeating: Bool)
}

class ExpanderView: UIView, NotificationHandler {

    weak var delegate: ExpanderViewDelegate? = nil
    var config: [ExpanderButtonItem]!
    var buttons: [ExpanderButton]!
    var scrollView = UIScrollView()
    var bottomBorderView = UIView()

    func standardInitialise() {
        translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        clipsToBounds = true
        isOpaque = true

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        bottomBorderView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)

        scrollView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        addSubview(bottomBorderView)

        bottomBorderView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        bottomBorderView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        bottomBorderView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        bottomBorderView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        bottomBorderView.backgroundColor = .lightGray

        heightAnchor.constraint(equalToConstant: 40).isActive = true

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

    var timers: [Int: Timer] = [:]
    var heldButtons: [Int] = []

    @objc func buttonDown(_ sender: ExpanderButton) {
        guard !heldButtons.contains(sender.type.rawValue) else {
            return
        }

        heldButtons.append(sender.type.rawValue)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.timers[sender.type.rawValue] != nil {
                return
            }
            if self.heldButtons.contains(sender.type.rawValue) {

                let timer = Timer.scheduledTimer(timeInterval: 0.15, target: self, selector: #selector(self.fireButton), userInfo: sender, repeats: true)
                self.timers[sender.type.rawValue] = timer
            }
        }
    }

    @objc func buttonUp(_ sender: ExpanderButton) {
        heldButtons.removeAll {
            $0 == sender.type.rawValue
        }
        let timer = timers.removeValue(forKey: sender.type.rawValue)
        if timer == nil {
            delegate?.expanderViewButtonTapped(type: sender.type, repeating: false)
        } else {
            timer!.invalidate()
        }
    }

    @objc func fireButton(_ sender: Timer) {
        let button = sender.userInfo as! ExpanderButton
        delegate?.expanderViewButtonTapped(type: button.type, repeating: true)
    }

    func layoutButtons() {

        for view in scrollView.subviews {
            view.removeFromSuperview()
        }

        buttons = []

        guard config != nil && !config.isEmpty else {
            return
        }

        var width: CGFloat = 10

        for item in config {
            if case .button(let factory) = item {
                let button = factory.getButton(xPosition: width)

                button.addTarget(self, action: #selector(buttonDown), for: .touchDown)
                button.addTarget(self, action: #selector(buttonUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

                scrollView.addSubview(button)

                buttons.append(button)

                width += button.frame.width
            } else {
                let image = UIImageView();

                image.frame = CGRect(x: width + 5, y: 5, width: 10, height: 30)
                image.image = #imageLiteral(resourceName: "delimiter").withRenderingMode(.alwaysTemplate)
                image.tintColor = userPreferences.currentTheme.tableViewDelimiterColor
                image.contentMode = .scaleAspectFit

                scrollView.addSubview(image)

                width += 20
            }
        }

        scrollView.contentSize.width = width
    }

    func getButton(typed type: ExpanderButtonItem.ButtonType) -> ExpanderButton! {
        for button in buttons where button.type == type {
            return button
        }

        return nil
    }

    func updateTheme() {

        for button in buttons {
            button.imageView?.tintColor = userPreferences.currentTheme.buttonDarkColor
        }
    }

    deinit {
        clearNotificationHandling()
    }
}
