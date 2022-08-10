//
//  TabViewTransformManager.swift
//  EasyHTML
//
//  Created by Артем on 04.08.2022.
//  Copyright © 2022 Артем. All rights reserved.
//

import Foundation

class TabViewTransformManager {
    var perspective: CGFloat = -0.0005
    var slideOffset: CGFloat = 0
    var rotation: CGFloat = 0
    var translateY: CGFloat = 0
    var scale: CGFloat = 0
    var zIndex: Int = 0
    
    private let zIndexModifier: CGFloat = 100
    
    func getTransform() -> CATransform3D {
        var transform = CATransform3DMakeTranslation(0, 0, CGFloat(zIndexModifier * CGFloat(zIndex)))
    
        if rotation != 0 {
            transform.m34 = perspective
            transform = CATransform3DRotate(transform, rotation, 1.0, 0.0, 0.0)
        }
        
        if translateY != 0.0 || slideOffset != 0.0 {
            transform = CATransform3DTranslate(transform, slideOffset, translateY, 0.0)
        }

        if scale != 0 {
            transform = CATransform3DScale(transform, scale, scale, scale)
        }

        return transform
    }
}
