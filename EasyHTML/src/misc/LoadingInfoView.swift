//
//  LoadingInfoView.swift
//  EasyHTML
//
//  Created by Артем on 04/10/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit


/// A layer that provides information about the loading process.
/// - note: Does not require setting `translatesAutoresizingMaskIntoConstraints = false`.
/// - note: Does not require setting `NSLayoutConstraints`.
class LoadingInfoView: UIView, NotificationHandler {

    let infoLabel = UILabel()
    let activityIndicator = UIActivityIndicatorView()

    func standardInitialise() {

        translatesAutoresizingMaskIntoConstraints = false
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        setupThemeChangedNotificationHandling()

        addSubview(infoLabel)
        addSubview(activityIndicator)

        infoLabel.font = UIFont.systemFont(ofSize: 14)
        infoLabel.textAlignment = .center
        infoLabel.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        infoLabel.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        infoLabel.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        infoLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 10).isActive = true
        activityIndicator.topAnchor.constraint(equalTo: topAnchor).isActive = true
        activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true

        activityIndicator.hidesWhenStopped = true

        activityIndicator.isHidden = true
        infoLabel.isHidden = true

        updateTheme()
    }

    func hide() {
        activityIndicator.stopAnimating()
        infoLabel.isHidden = true
    }

    func fade() {
        infoLabel.isHidden = false
        activityIndicator.isHidden = false

        activityIndicator.alpha = 0.0
        infoLabel.alpha = 0.0

        activityIndicator.startAnimating()
        UIView.animate(withDuration: 0.5) {
            self.activityIndicator.alpha = 1.0
        }

        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
            self.infoLabel.alpha = 1.0
        })
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        standardInitialise()
    }

    override func didMoveToSuperview() {

        guard superview != nil else {
            return
        }

        centerYAnchor.constraint(equalTo: superview!.centerYAnchor).isActive = true
        leftAnchor.constraint(equalTo: superview!.leftAnchor, constant: 10).isActive = true
        rightAnchor.constraint(equalTo: superview!.rightAnchor, constant: -10).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        standardInitialise()
    }

    func updateTheme() {

        infoLabel.textColor = userPreferences.currentTheme.secondaryTextColor
        activityIndicator.style = userPreferences.currentTheme.isDark ? .white : .gray
    }

    deinit {
        clearNotificationHandling()
    }
}
