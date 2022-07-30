//
//  WarningSign.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

extension FilesRelocationManager {
    class WarningSign: UIVisualEffectView {
        internal let label: UILabel
        internal var onClose: (() -> ())!

        private func initialize() {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textAlignment = .center
            label.numberOfLines = -1

            contentView.addSubview(label)

            label.topAnchor.constraint(equalTo: topAnchor, constant: 7).isActive = true
            label.leftAnchor.constraint(equalTo: leftAnchor, constant: 10).isActive = true
            label.rightAnchor.constraint(equalTo: rightAnchor, constant: -10).isActive = true
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7).isActive = true

            label.textColor = UIColor(white: 0.5, alpha: 0.7)

            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))
        }

        override init(effect: UIVisualEffect?) {

            label = UILabel()
            let effect = UIBlurEffect(style: userPreferences.currentTheme.isDark ? .dark : .light)

            super.init(effect: effect)

            initialize()
        }

        @objc func close() {
            onClose?()
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
