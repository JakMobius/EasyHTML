//
//  InstantPanGestureRecognizer.swift
//  EasyHTML
//
//  Created by Артем on 09.05.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class InstantTapGestureRecognizer: UITapGestureRecognizer {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began {
            return
        }
        super.touchesBegan(touches, with: event)
        self.state = .began
    }
}
