//
//  WebEditorSessionDispatcher.swift
//  EasyHTML
//
//  Created by Артем on 07.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

class WebEditorSessionDispatcher: SourceCodeEditorSessionDispatcher, ConsoleDelegate {
    
    internal var isWebpage = false
    internal var isScript = false
    internal var isBrowser = false
    
    override var session: SourceCodeEditorSession? {
        didSet {
            
            if let file = session?.file {
                let ext = file.url.pathExtension
                isWebpage = ext == "html" || ext == "htm"
                isScript = isWebpage || ext == "js"
                isBrowser = isWebpage || ext == "txt" || ext == "svg"
            } else {
                isWebpage = false
                isScript = false
                isBrowser = false
            }
        }
    }
    
    func console(executed command: String) {
        browserViewController?.webView?.evaluateJavaScript("""
            !function(){
            try {
            var r = eval(\"\(command)\")
            EasyHTML._s([r],5)
            } catch(e) {
            EasyHTML._s([e],2)
            }
            }()
            
            """)
    }
    
    func reloadConsole() {
        browserViewController?.reload()
    }
    
    func unreadMessagesCount(count: Int) {
        let string = count == 0 ? nil : String(count)
        
        for observer in observers {
            observer.tabBar.items?.last?.badgeValue = string
        }
    }
    
}
