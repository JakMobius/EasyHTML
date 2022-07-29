//
//  ConsoleExecuteField.swift
//  EasyHTML
//
//  Created by Артем on 11/04/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

class ConsoleMessage {
    var date: String
    var body: NSMutableAttributedString
    var type: Int
    
    init(date: String, body: NSMutableAttributedString, type: Int) {
        self.date = date
        self.body = body
        self.type = type
    }
    
    static private func getCurrentDate() -> String {
        let components = Calendar.current.dateComponents([Calendar.Component.hour, Calendar.Component.minute, Calendar.Component.second], from: Date())
        let h = components.hour ?? 0
        let m = components.minute ?? 0
        let s = components.second ?? 0
        
        return "\(h<10 ?"0\(h)":"\(h)"):\(m<10 ?"0\(m)":"\(m)"):\(s<10 ?"0\(s)":"\(s)")"
    }
    
    init(body: NSMutableAttributedString, type: Int) {
        self.body = body
        self.type = type
        self.date = ConsoleMessage.getCurrentDate()
    }
}

class ConsoleCacheItem {
    var text: String
    var cursorPosition: UITextRange
    
    init(field: ConsoleExecuteField) {
        if(field.placeholderShown) {
            self.text = ""
        } else {
            self.text = field.text!
        }
        
        if(field.selectedTextRange == nil) {
            self.cursorPosition = field.textRange(from: field.endOfDocument, to: field.endOfDocument)!
        } else {
            self.cursorPosition = field.selectedTextRange!
        }
    }
}

class ConsoleExecuteField: UITextView, NotificationHandler {
    
    var placeholderShown = false
    var placeholdertext = localize("consoleplaceholder")
    
    final func showPlaceholder() {
        guard !placeholderShown else { return }
        placeholderShown = true
        
        text = placeholdertext
        textColor = userPreferences.currentTheme.secondaryTextColor.withAlphaComponent(0.5)
    }
    
    final func hidePlaceholder() {
        guard placeholderShown else { return }
        placeholderShown = false
        
        text = nil
        textColor = userPreferences.currentTheme.cellTextColor
    }
    
    func updateTheme() {
        
        if(placeholderShown) {
            textColor = userPreferences.currentTheme.secondaryTextColor.withAlphaComponent(0.5)
        } else {
            textColor = userPreferences.currentTheme.cellTextColor
        }
    }
    
    func standardInitialise() {
        showPlaceholder()
        setupThemeChangedNotificationHandling()
        
        textContainerInset.left = 7
        if #available(iOS 11.0, *) {
            smartInsertDeleteType = .no
            dataDetectorTypes = []
            smartQuotesType = .no
        }
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        
        standardInitialise()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        standardInitialise()
    }
    
    deinit {
        clearNotificationHandling()
    }
}
