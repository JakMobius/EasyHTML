//
//  EditorKeyCommands.swift
//  EasyHTML
//
//  Created by Артем on 24/11/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

struct WebViewActions {
    static let inputAction = "i"
    static let cursorAction = "r"
    static let gradientAction = "g"
    static let colorAction = "c"
    static let didFinishLoadAction = "l"
    static let consoleClearAction = "q"
    static let consoleMessageAction = "m"
    static let scrollAction = "s"
}

extension EditorViewController {
    struct KeyCommands {
        static let undo = UIKeyCommand(input: "z",  modifierFlags: .command, action: #selector(EditorViewController.dummy), discoverabilityTitle: localize("undo", .editor))
        static let redo = UIKeyCommand(input: "z",  modifierFlags: [.command, .shift], action: #selector(EditorViewController.dummy), discoverabilityTitle: localize("redo", .editor))
        static let searchInCode = UIKeyCommand(input: "f",  modifierFlags: [.command], action: #selector(EditorViewController.searchInCodeKeyAction), discoverabilityTitle: localize("search", .editor))
        static let replaceInCode = UIKeyCommand(input: "f",  modifierFlags: [.alternate, .command], action: #selector(EditorViewController.replaceInCodeKeyAction), discoverabilityTitle: localize("replace", .editor))
        static let commentOut = UIKeyCommand(input: "/",  modifierFlags: .command, action: #selector(EditorViewController.smartComment), discoverabilityTitle: localize("commentOut", .editor))
        static let save = UIKeyCommand(input: "s",  modifierFlags: .command, action: #selector(EditorViewController.save), discoverabilityTitle: localize("save", .editor))
        static let insertlineafter = UIKeyCommand(input: "\r", modifierFlags: .command, action: #selector(EditorViewController.insertlineafter), discoverabilityTitle: localize("insertlineafter", .editor))
        static let insertlinebefore = UIKeyCommand(input: "\r", modifierFlags: [.shift, .command], action: #selector(EditorViewController.insertlinebefore), discoverabilityTitle: localize("insertlinebefore", .editor))
        static let selectline = UIKeyCommand(input: "l",  modifierFlags: .command, action: #selector(EditorViewController.selectline), discoverabilityTitle: localize("selectline", .editor))
        static let duplicateline = UIKeyCommand(input: "d",  modifierFlags: [.shift, .command], action: #selector(EditorViewController.duplicateline), discoverabilityTitle: localize("duplicateline", .editor))
        static let jumptobracket = UIKeyCommand(input: "m",  modifierFlags: .command, action: #selector(EditorViewController.jumptobracket), discoverabilityTitle: localize("jumptobracket", .editor))
        static let selectScope = UIKeyCommand(input: " ", modifierFlags: [.shift, .command], action: #selector(EditorViewController.selectScope), discoverabilityTitle: localize("selectScope", .editor))
        static let goLineStartSmart = UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: .command, action: #selector(EditorViewController.goLineStartSmart))
        
        static let expandAbbreviation = UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(EditorViewController.triggerTab), discoverabilityTitle: localize("expandAbbreviation", .editor))
        static let balanceOutward = UIKeyCommand(input: "d", modifierFlags: [.command], action: #selector(EditorViewController.balanceOutward), discoverabilityTitle: localize("balanceOutward", .editor))
        static let balanceInward = UIKeyCommand(input: "d", modifierFlags: [.shift, .command], action: #selector(EditorViewController.balanceInward), discoverabilityTitle: localize("balanceInward", .editor))
        static let wrapWithAbbreviation = UIKeyCommand(input: "a", modifierFlags: [.shift, .command], action: #selector(EditorViewController.wrapWithAbbreviation), discoverabilityTitle: localize("wrapWithAbbreviation", .editor))
        static let selectNextItem = UIKeyCommand(input: ".", modifierFlags: [.shift, .command], action: #selector(EditorViewController.nextItem), discoverabilityTitle: localize("selectNextItem", .editor))
        static let selectPreviousItem = UIKeyCommand(input: ",", modifierFlags: [.shift, .command], action: #selector(EditorViewController.prevItem), discoverabilityTitle: localize("selectPrevItem", .editor))
        static let nextEditPoint = UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [.shift, .command], action: #selector(EditorViewController.nextEditPoint), discoverabilityTitle: localize("nextEditPoint", .editor))
        static let prevEditPoint = UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [.shift, .command], action: #selector(EditorViewController.prevEditPoint), discoverabilityTitle: localize("prevEditPoint", .editor))
        static let reflectCSSValue = UIKeyCommand(input: "b", modifierFlags: [.command], action: #selector(EditorViewController.reflectCSSValue), discoverabilityTitle: localize("reflectCSSValue", .editor))
        static let solveMathExpression = UIKeyCommand(input: "y", modifierFlags: [.command, .shift], action: #selector(EditorViewController.solveMathExpression), discoverabilityTitle: localize("solveMathExpression", .editor))
        
        static let fontup = UIKeyCommand(input: "+", modifierFlags: [.command], action: #selector(EditorViewController.fontup))
        static let fontdown = UIKeyCommand(input: "-", modifierFlags: [.command], action: #selector(EditorViewController.fontdown))
        
        // Ниже некоторые сочетания клавиш, которые не совсем корректно работают нативно в CodeMirror
        
        static let goWordLeft = UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [.alternate], action: #selector(EditorViewController.goWordLeft))
        static let goWordRight = UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [.alternate], action: #selector(EditorViewController.goWordRight))
        
        static let selectWordLeft = UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [.alternate, .shift], action: #selector(EditorViewController.selectWordLeft))
        static let selectWordRight = UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [.alternate, .shift], action: #selector(EditorViewController.selectWordRight))
        
        static let goToDocumentStartCmd = UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [.command], action: #selector(EditorViewController.jumpToDocumentStart))
        static let goToDocumentEndCmd = UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [.command], action: #selector(EditorViewController.jumpToDocumentEnd))
        
        static let goToDocumentStartCtrl = UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [.control], action: #selector(EditorViewController.jumpToDocumentStart))
        static let goToDocumentEndCtrl = UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [.control], action: #selector(EditorViewController.jumpToDocumentEnd))
        
        static let deleteLineBeforeCursor = UIKeyCommand(input: "\u{08}" /* \b */, modifierFlags: [.command], action: #selector(EditorViewController.deleteLineBeforeCursor))
        
        static let goCharLeft = UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(EditorViewController.goCharLeft))
        static let goCharRight = UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(EditorViewController.goCharRight))
        static let goLineUp = UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(EditorViewController.goLineUp))
        static let goLineDown = UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(EditorViewController.goLineDown))
    }
}
