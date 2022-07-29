//
//  ExpanderCollectionView.swift
//  EasyHTML
//
//  Created by Артем on 23.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

enum ExpanderButton {
    case button(image: String, action: Selector?, defaultOn: (() -> (Bool))?)
    case delimiter
}
