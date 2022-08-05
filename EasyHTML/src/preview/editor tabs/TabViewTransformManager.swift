//
//  TabViewTransformManager.swift
//  EasyHTML
//
//  Created by Артем on 04.08.2022.
//  Copyright © 2022 Артем. All rights reserved.
//

import Foundation

class TabViewTransformManager {
    var slideOffset: CGFloat = 0
    
    func getTransform() -> CATransform3D {
        return CATransform3DIdentity;
    }
}
