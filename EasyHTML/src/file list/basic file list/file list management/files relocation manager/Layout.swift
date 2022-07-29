//
//  Layout.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

extension FilesRelocationManager {
    enum Layout {
        case normal(size: CGFloat)
        case horizontal
    }
    
    final func switchToVerticalLayout() {
        UIView.animate(withDuration: 0.3, animations: {
            
            /*
             Восстановление порядка чайлдов в UIScrollView
             */
            
            let filesCount = min(self.maximumStackedFiles, self.replicationViews.count)
            
            self.currentLayout = .normal(size: 20)
            
            for i in 0 ..< filesCount {
                let subview = self.replicationViews[i]
                if subview.superview == nil {
                    self.replicationViewsContainer.addSubview(subview)
                } else {
                    self.replicationViewsContainer.bringSubviewToFront(subview)
                }
                
                let transform = subview.transform
                subview.transform = .identity
                
                subview.frame.origin.x = 10
                subview.frame.origin.y = 5
                
                subview.transform = transform
            }
            
            self.layout()
        })
        
        self.hintType = .normal
        
        if shouldPreviewGuide {
            self.showGuideMessage()
        } else {
            self.removeGuide()
        }
    }
    
    final func switchToHorizontalLayout() {
        currentLayout = .horizontal
        
        UIView.animate(withDuration: 0.5) {
            for view in self.replicationViews {
                view.transform = .identity
            }
            self.layout(force: true)
        }
        
        isMovingVertical = false
        isMovingHorizontal = false
        
        hintType = .horizontal
        
        if shouldPreviewHorizontalGuide {
            showGuideMessage()
        } else {
            removeGuide()
        }
    }
}
