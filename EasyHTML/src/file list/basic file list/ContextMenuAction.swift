//
//  ContextMenuAction.swift
//  EasyHTML
//
//  Created by Артем on 10/09/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

internal class ContextMenuAction: NSObject {
    var style: UIAlertAction.Style
    var title = ""
    var callback: ((_: ContextMenuAction) -> ())! = nil
    
    convenience init(title: String, callback: ((_: ContextMenuAction) -> ())! = nil) {
        self.init(title: title, style: .default, callback: callback)
    }
    
    internal init(title: String, style: UIAlertAction.Style, callback: ((_: ContextMenuAction) -> ())! = nil) {
        self.title = title
        self.style = style
        self.callback = callback
    }
    
    internal static func shareAction(callback: ((_: ContextMenuAction) -> ())!) -> ContextMenuAction {
        return .init(title: localize("share"), callback: callback)
    }
    
    internal static func openAction(callback: ((_: ContextMenuAction) -> ())!) -> ContextMenuAction {
        return .init(title: localize("open"), callback: callback)
    }
    
    internal static func openInNewTabAction(callback: ((_: ContextMenuAction) -> ())!) -> ContextMenuAction {
        return .init(title: localize("openinnewtab"), callback: callback)
    }
    
    internal static func quickZipAction(callback: ((_: ContextMenuAction) -> ())!) -> ContextMenuAction {
        return .init(title: localize("quickzip"), callback: callback)
    }
    
    internal static func showContentAction(callback: ((_: ContextMenuAction) -> ())!) -> ContextMenuAction {
        return .init(title: localize("showcontent"), callback: callback)
    }
    
    internal static func showSourceAction(callback: ((_: ContextMenuAction) -> ())!) -> ContextMenuAction {
        return .init(title: localize("showsource"), callback: callback)
    }
    
    internal static func moveAction(callback: ((_: ContextMenuAction) -> ())!) -> ContextMenuAction {
        return .init(title: localize("movefile"), callback: callback)
    }
    
    internal static func copyAction(callback: ((_: ContextMenuAction) -> ())!) -> ContextMenuAction {
        return .init(title: localize("copyfile"), callback: callback)
    }
}
