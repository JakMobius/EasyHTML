//
//  ExpanderButton.swift
//  EasyHTML
//
//  Created by Артем on 03/10/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class ExpanderButton: UIButton {
    var type: ExpanderButtonItem.ButtonType!
}

class ExpanderButtonFactory: NSObject {
    var type: ExpanderButtonItem.ButtonType

    var customImage: UIImage?

    init(type: ExpanderButtonItem.ButtonType) {
        self.type = type
    }

    func getButton(xPosition: CGFloat) -> ExpanderButton {
        let button = ExpanderButton()

        button.imageView!.tintColor = userPreferences.currentTheme.buttonDarkColor
        button.imageView!.contentMode = .scaleAspectFit
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.setImage(type.image ?? customImage, for: .normal)
        button.isEnabled = type.isEnabledByDefault
        button.frame = CGRect(x: xPosition, y: 0, width: max(button.imageView!.image!.size.width + 8, 10), height: 40)
        button.type = type

        return button
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}

enum ExpanderButtonItem {
    case button(_ button: ExpanderButtonFactory)
    case delimiter

    enum ButtonType: Int {

        case undo = 0
        case redo = 1
        case save = 2
        case colorpicker = 3
        case gradientpicker = 4
        case search = 5
        case replace = 6
        case fontup = 7
        case fontdown = 8
        case bracketleft = 9
        case bracketright = 10
        case curvedbracketleft = 11
        case curvedbracketright = 12
        case squarebracketleft = 13
        case squarebracketright = 14
        case greaterthan = 15
        case lessthan = 16
        case quote = 17
        case goSymbolLeft = 18
        case goSymbolRight = 19
        case tab = 20
        case indent = 21
        case singlequote = 22
        case goToDocumentStart = 23
        case goToDocumentEnd = 24
        case commentLine = 25

        static let allButtons: [ExpanderButtonItem.ButtonType] = [
            .undo,
            .redo,
            .save,
            .colorpicker,
            .gradientpicker,
            .search,
            .replace,
            .fontup,
            .fontdown,
            .bracketleft,
            .bracketright,
            .curvedbracketleft,
            .curvedbracketright,
            .squarebracketleft,
            .squarebracketright,
            .greaterthan,
            .lessthan,
            .quote,
            .singlequote,
            .goSymbolLeft,
            .goSymbolRight,
            .tab,
            .indent,
            .goToDocumentEnd,
            .goToDocumentStart,
            .commentLine
        ]

        static let typeImages: [UIImage] = {
            var imageNames = [
                "undo",
                "redo",
                "save",
                "colorpicker",
                "gradientpicker",
                "search",
                "replace",
                "fontup",
                "fontdown",
                "bracketleft",
                "bracketright",
                "curvedbracketleft",
                "curvedbracketright",
                "squarebracketleft",
                "squarebracketright",
                "greaterthan",
                "lessthan",
                "quote",
                "goLeft",
                "goRight",
                "tab",
                "indent",
                "singlequote",
                "goToDocumentStart",
                "goToDocumentEnd",
                "commentLine"
            ]

            return imageNames.map({ UIImage(named: $0)?.withRenderingMode(.alwaysTemplate) ?? UIImage() })
        }()

        var image: UIImage? {
            ExpanderButtonItem.ButtonType.typeImages[rawValue]
        }

        var isEnabledByDefault: Bool {
            switch self {
            case .save: return false
            case .fontup: return userPreferences.fontSize < 20
            case .fontdown: return userPreferences.fontSize > 10
            default: return true
            }
        }
    }
}
