//
//  ExpanderCollectionView.swift
//  EasyHTML
//
//  Created by Темыч on 23.12.2017.
//  Copyright © 2017 Темыч. All rights reserved.
//

import UIKit

enum ExpanderButton {
    case button(image: String, action: Selector?, defaultOn: (() -> (Bool))?)
    case delimiter
}
