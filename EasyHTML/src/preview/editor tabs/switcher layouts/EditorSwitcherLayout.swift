//
//  EditorSwitcherLayout.swift
//  EasyHTML
//
//  Created by Артем on 09.08.2022.
//  Copyright © 2022 Артем. All rights reserved.
//

import Foundation

class EditorSwitcherLayout {
    var switcher: EditorSwitcherView! = nil
    
    func frameFor(editorView: EditorTabView) -> CGRect {
        fatalError("Subclasses need to implement the `frameFor(editorView:)` method.")
    }
    
    func update() {
        
    }
    
    func scrollViewContentSize() -> CGSize {
        return .zero
    }
    
    func scrollViewMinZoomScale() -> CGFloat {
        return 1.0
    }
    
    func updateTransformFor(editorView: EditorTabView) {
        
    }
}
