//
//  GitHubRepositoryLanguagesDiagram.swift
//  EasyHTML
//
//  Created by Артем on 30/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubRepositoryController {
    class LanguagesDiagram: UIView {
        
        var colors = [(color: CGColor, fraction: CGFloat)]()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
            setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
            setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
            setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
        
        func setLanguages(languages: [GitHubLanguageItem]) {
            self.colors.removeAll()
            
            for language in languages {
                let color = GitHubUtils.colorFor(language: language.language) ?? .gray
                
                colors.append((color: color.cgColor, fraction: CGFloat(language.fraction)))
            }
            
            setNeedsDisplay()
        }
        
        override func draw(_ rect: CGRect) {
            
            super.draw(rect)
            
            guard let context = UIGraphicsGetCurrentContext() else { return };
            
            var oldpos: CGFloat = 0
            
            for color in colors {
                context.setFillColor(color.color)
                
                let pos = color.fraction * self.frame.size.width
                
                context.fill(CGRect(x: oldpos, y: 0, width: pos, height: self.frame.size.height))
                
                oldpos += pos
            }
        }
    }
}
