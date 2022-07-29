//
//  EditorHelperFunctions.swift
//  EasyHTML
//
//  Created by Артем on 03/10/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

extension EditorViewController {
    func showGradientpicker() {
        
        guard let button = expanderView.getButton(typed: .gradientpicker) else { return }
        
        webView.resignFirstResponder()
        
        let controller = PrimarySplitViewController.instance(for: view)!
        
        let view = UIView(frame: button.superview!.convert(button.frame, to: controller.view))
        view.frame.origin.y += 50
        
        GradientPicker.present(from: controller, origin: view).setGradientPickerDelegate(self)
    }
    
    func showColorpicker() {
        
        guard let button = expanderView.getButton(typed: .colorpicker) else { return }
        
        webView.resignFirstResponder()
        
        let controller = PrimarySplitViewController.instance(for: view)!
        
        let view = UIView(frame: button.superview!.convert(button.frame, to: controller.view))
        view.frame.origin.y += 50
        
        ColorPicker.present(from: controller, origin: view).setDelegate(delegate: self)
    }
    
    // MARK: Функции редактора
    
    @objc func triggerTab() {
        webView.evaluateJavaScript("""
            editor.triggerOnKeyDown({keyCode:9});editor.triggerOnKeyUp({keyCode:9})
        """)
    }
    
    @objc func insertlineafter() {
        executeCommand("insertLineAfter")
    }
    
    @objc func insertlinebefore() {
        executeCommand("insertLineBefore")
    }
    
    @objc func selectline() {
        executeCommand("selectLine")
    }
    
    @objc func duplicateline() {
        executeCommand("duplicateLine")
    }
    
    @objc func jumptobracket() {
        executeCommand("selectScope")
    }
    
    @objc func selectScope() {
        executeCommand("selectScope")
    }
    
    @objc func balanceOutward() {
        executeCommand("emmet.balance_outward")
    }
    
    @objc func balanceInward() {
        executeCommand("emmet.balance_inward")
    }
    
    @objc func wrapWithAbbreviation() {
        executeCommand("emmet.wrap_with_abbreviation")
    }
    
    @objc func goLineStartSmart() {
        executeCommand("goLineStartSmart")
    }
    
    @objc func nextItem() {
        executeCommand("emmet.select_next_item")
    }
    
    @objc func prevItem() {
        executeCommand("emmet.select_prev_item")
    }
    
    @objc func nextEditPoint() {
        executeCommand("emmet.next_edit_point")
    }
    
    @objc func prevEditPoint() {
        executeCommand("emmet.prev_edit_point")
    }
    
    @objc func goWordLeft() {
        executeCommand("goGroupLeft")
    }
    
    @objc func goWordRight() {
        executeCommand("goGroupRight")
    }
    
    @objc func selectWordLeft() {
        webView.evaluateJavaScript("""
            editor.operation(function() {
                var s=editor.getCursor(false);
                editor.setCursor(editor.getCursor(true));
                editor.execCommand("goGroupLeft");
                editor.setSelection(editor.getCursor(true), s);
            })
        """, completionHandler: nil)
    }
    
    @objc func selectWordRight() {
        webView.evaluateJavaScript("""
            editor.operation(function() {
                var s=editor.getCursor(true);
                editor.setCursor(editor.getCursor(false));
                editor.execCommand("goGroupRight");
                editor.setSelection(editor.getCursor(false), s);
            })
        """, completionHandler: nil)
    }
    
    @objc func jumpToDocumentStart() {
        executeCommand("goDocStart")
    }
    
    @objc func jumpToDocumentEnd() {
        executeCommand("goDocEnd")
    }
    
    @objc func deleteLineBeforeCursor() {
        executeCommand("delWrappedLineLeft")
    }
    
    @objc func goCharLeft() {
        executeCommand("goCharLeft")
    }
    
    @objc func goCharRight() {
        executeCommand("goCharRight")
    }
    
    @objc func goLineUp() {
        executeCommand("goLineUp")
    }
    
    @objc func goLineDown() {
        executeCommand("goLineDown")
    }
    
    @objc func fontup() {
        if(userPreferences.fontSize < 20) {
            userPreferences.fontSize += 1
            updateFontSize()
        }
    }
    
    @objc func fontdown() {
        if(userPreferences.fontSize > 10) {
            userPreferences.fontSize -= 1
            updateFontSize()
        }
    }
    
    @objc func reflectCSSValue() {
        executeCommand("emmet.reflect_css_value")
    }
    
    @objc func solveMathExpression() {
        executeCommand("emmet.evaluate_math_expression")
    }
    
    @objc func smartComment() {
        if(self.emmetEnabled) {
            webView.evaluateJavaScript("var n=editor.getModeAt(editor.getCursor()).name;if(n=='xml'||n=='css'){editor.execCommand('emmet.toggle_comment')}else{editor.toggleComment({indent:true})}", completionHandler: nil)
        } else {
            commentOut()
        }
    }
    
    func emmetCommentOut() {
        executeCommand("emmet.toggle_comment")
    }
    
    func commentOut() {
        webView.evaluateJavaScript("editor.toggleComment({indent:true})", completionHandler: nil)
    }
    
    @objc func undoButtonAction() {
        performUndo()
        
        undoManager?.undo()
    }
    
    @objc func redoButtonAction() {
        performRedo()
        
        undoManager?.redo()
    }
    
    @objc func save() {
        saveFile()
    }
}
