//
//  WebKitKeyboardSwizzle.swift
//  EasyHTML
//
//  Created by Артем on 16/03/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit
import WebKit

typealias OldClosureType = @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Any?) -> Void
typealias NewClosureType = @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void

class SwizzledWebView: WKWebView {
    
    override func selectAll(_ sender: Any?) {
        evaluateJavaScript("editor.execCommand('selectAll')", completionHandler: nil)
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        
        if
            action == #selector(UIResponderStandardEditActions.select(_:)) ||
            action == #selector(UIResponderStandardEditActions.selectAll(_:)) ||
            action == #selector(UIResponderStandardEditActions.copy(_:)) ||
            action == #selector(UIResponderStandardEditActions.paste(_:)) ||
            action == #selector(UIResponderStandardEditActions.cut(_:))  {
            return super.canPerformAction(action, withSender: sender) // super.canPerformAction
        }
        
        if
            action == #selector(searchOccurrences) ||
            action == #selector(replaceOccurrences) {
            return super.canPerformAction(#selector(UIResponderStandardEditActions.copy), withSender: sender)
        }
        
        return false
    }
    
    @objc func searchOccurrences() {
        evaluateJavaScript("editor.getSelection()") { (result, error) in
            guard let result = result as? String else { return }
            
            guard let controller = self.parentViewController as? EditorViewController else { return }
            
            controller.searchInCode(text: result)
        }
    }
    
    @objc func replaceOccurrences() {
        evaluateJavaScript("editor.getSelection()") { (result, error) in
            guard let result = result as? String else { return }
            
            guard let controller = self.parentViewController as? EditorViewController else { return }
            
            controller.replaceInCode(text: result)
        }
    }
    
    @objc func customSelect(sender: Any?) {
        self.select(sender)
    }
    
    @objc func customSelectAll(sender: Any?) {
        self.selectAll(sender)
    }
    
    @objc func customCopy(sender: Any?) {
        self.copy(sender)
    }
    
    @objc func customPaste(sender: Any?) {
        self.paste(sender)
    }
    
    @objc func customCut(sender: Any?) {
        self.cut(sender)
    }
    
    private var _keyboardDisplayRequiresUseraction = true
    
    var keyboardDisplayRequiresUserAction: Bool? {
        get {
            return _keyboardDisplayRequiresUseraction
        }
        set {
            _keyboardDisplayRequiresUseraction = newValue ?? true
            setKeyboardRequiresUserInteraciton(_keyboardDisplayRequiresUseraction)
        }
    }
    
    private func setKeyboardRequiresUserInteraciton(_ value: Bool) {
        guard let WKContentViewClass: AnyClass = NSClassFromString("WKContentView") else {
            return print("Cannot find WKContentView class")
        }
        
        let oldSelector: Selector = sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:")
        let newSelector: Selector = sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:changingActivityState:userObject:")
        
        if let method = class_getInstanceMethod(WKContentViewClass, oldSelector) {
            let originalImp: IMP = method_getImplementation(method)
            let original: OldClosureType = unsafeBitCast(originalImp, to: OldClosureType.self)
            let block: @convention(block) (Any, UnsafeRawPointer, Bool, Bool, Any?) -> Void = { (me, arg0, arg1, arg2, arg3) in
                original(me, oldSelector, arg0, !value, arg2, arg3)
            }
            let imp: IMP = imp_implementationWithBlock(block)
            method_setImplementation(method, imp)
        }
        if let method = class_getInstanceMethod(WKContentViewClass, newSelector) {
            let originalImp: IMP = method_getImplementation(method)
            let original: NewClosureType = unsafeBitCast(originalImp, to: NewClosureType.self)
            let block: @convention(block) (Any, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void = { (me, arg0, arg1, arg2, arg3, arg4) in
                original(me, newSelector, arg0, !value, arg2, arg3, arg4)
            }
            let imp: IMP = imp_implementationWithBlock(block)
            method_setImplementation(method, imp)
        }
    }
}
