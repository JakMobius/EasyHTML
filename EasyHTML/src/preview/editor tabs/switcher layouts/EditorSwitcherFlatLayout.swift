//
//  EditorSwitcherFlatLayout.swift
//  EasyHTML
//
//  Created by Артем on 03.08.2022.
//  Copyright © 2022 Артем. All rights reserved.
//

import Foundation

class EditorSwitcherFlatLayout : EditorSwitcherLayout {
    
    private let verticalPadding: CGFloat = 50
    private let horizontalPadding: CGFloat = 50
    private var blocksInLine: CGFloat = 0
    private var maxBlocksInLine: CGFloat = 0
    private var paddedBlockHeight: CGFloat = 0
    private var paddedBlockWidth: CGFloat = 0
    private let minBlockWidth: CGFloat = 150
    
    override func frameFor(editorView: EditorTabView) -> CGRect {
        let x = editorView.index % Int(blocksInLine)
        let y = editorView.index / Int(blocksInLine)

        let realX = CGFloat(x) * paddedBlockWidth + horizontalPadding
        let realY = CGFloat(y) * paddedBlockHeight + verticalPadding

        return CGRect(x: realX, y: realY, width: switcher.bounds.width, height: switcher.bounds.height)
    }
    
    override func update() {
        let paddedBoundsWidth = switcher.bounds.width - horizontalPadding
        let paddedMinBlockWidth = minBlockWidth + horizontalPadding
        paddedBlockWidth = switcher.bounds.width + horizontalPadding
        paddedBlockHeight = switcher.bounds.height + verticalPadding

        maxBlocksInLine = min(floor(paddedBoundsWidth / paddedMinBlockWidth), 3)

        blocksInLine = max(1, min(maxBlocksInLine, CGFloat(switcher.containerViews.count)))
    }
    
    private func getScrollViewContentWidth() -> CGFloat {
        let realBlockWidth = switcher.bounds.width + horizontalPadding
        return realBlockWidth * blocksInLine + horizontalPadding
    }
    
    override func scrollViewContentSize() -> CGSize {
        let realBlockHeight = switcher.bounds.height + verticalPadding

        var scrollViewContentSizeHeight: CGFloat

        let height1 = switcher.bounds.height

        if blocksInLine <= 1 {
            scrollViewContentSizeHeight = height1
        } else {
            var height2 = realBlockHeight * ceil(CGFloat(switcher.containerViews.count) / blocksInLine) * switcher.scrollView.minimumZoomScale

            height2 += 2 * verticalPadding

            scrollViewContentSizeHeight = max(height1, height2)
        }
        
        return .init(width: getScrollViewContentWidth(), height: scrollViewContentSizeHeight)
    }
    
    override func scrollViewMinZoomScale() -> CGFloat {
        return switcher.bounds.width / getScrollViewContentWidth()
    }
    
    override func updateTransformFor(editorView: EditorTabView) {
        editorView.transformManager.translateY = 0
        editorView.transformManager.rotation = 0
        editorView.transformManager.scale = 1
    }
}
