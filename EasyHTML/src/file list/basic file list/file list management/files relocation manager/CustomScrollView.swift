//
//  CustomScrollView.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

extension FilesRelocationManager {
    internal class CustomScrollView: UIScrollView {
        override internal func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let view = super.hitTest(point, with: event)
            return view == self ? nil : view
        }
    }

    final func setupScrollView() {
        replicationViewsContainer.showsVerticalScrollIndicator = false
        replicationViewsContainer.showsHorizontalScrollIndicator = false
        replicationViewsContainer.translatesAutoresizingMaskIntoConstraints = false
        replicationViewsContainer.clipsToBounds = false
        replicationViewsContainer.delegate = self

        parent.view.addSubview(replicationViewsContainer)

        let bottomAnchor: NSLayoutYAxisAnchor

        if #available(iOS 11.0, *) {
            bottomAnchor = parent.view.safeAreaLayoutGuide.bottomAnchor
        } else {
            bottomAnchor = parent.view.bottomAnchor
        }

        replicationViewsContainer.leftAnchor.constraint(equalTo: parent.view.leftAnchor).isActive = true
        replicationViewsContainer.rightAnchor.constraint(equalTo: parent.view.rightAnchor).isActive = true
        replicationViewsContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -40).isActive = true
        replicationViewsContainer.heightAnchor.constraint(equalToConstant: 150).isActive = true

        parent.view.layoutSubviews()
    }
}
