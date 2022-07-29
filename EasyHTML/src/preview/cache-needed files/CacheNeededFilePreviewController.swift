 //
 //  AnotherFilePreviewController.swift
 //  EasyHTML
 //
 //  Created by Артем on 10.03.2018.
 //  Copyright © 2018 Артем. All rights reserved.
 //
 
 import UIKit
 import WebKit
 
 class CacheNeededFilePreviewController: AnotherFilePreviewController {
    
    private var temproraryFileURL: URL! = nil
    
    @objc override func loadData() {
        loadingInfoView.fade()
        
        messageManager.reset()
        
        if self.file!.url.isFileURL && false {
            
            let path = NSString(string: applicationPath).deletingLastPathComponent
            
            webView.loadFileURL(self.file!.url, allowingReadAccessTo: URL(fileURLWithPath: path))
        } else {
            
            let tempDirPath = NSTemporaryDirectory()
            
            var fileDir: String
            repeat {
                fileDir = tempDirPath + UUID().uuidString
            } while(fileOrFolderExist(name: fileDir))
            
            if !file!.url.pathExtension.isEmpty {
                fileDir += "." + self.file!.url.pathExtension
            }
            
            self.temproraryFileURL = URL(fileURLWithPath: fileDir)
            
            let loadingInfo = localize("loadingstep_downloading", .editor)
            
            loadingInfoView.infoLabel.text = loadingInfo.replacingOccurrences(of: "#", with: "0")
            
            self.ioManager.readFileAt(url: self.file!.url, completion: {
                (data, error) in
                self.loadingInfoView.hide()
                self.webView.isHidden = false
                if let data = data {
                    try? data.write(to: self.temproraryFileURL!, options: Data.WritingOptions.atomic)
                    
                    self.webView.loadFileURL(self.temproraryFileURL!, allowingReadAccessTo: URL(fileURLWithPath: tempDirPath))
                } else {
                    self.loadingErrorHandler(error: error)
                }
            }, progress: {
                prog in
                self.loadingInfoView.infoLabel.text = loadingInfo.replacingOccurrences(of: "#", with: String(Int(prog.fractionCompleted * 100)))
            })
        }
    }
    
    deinit {
        webView?.stopLoading()
        webView?.uiDelegate = nil
        webView?.navigationDelegate = nil
        webView?.loadHTMLString("", baseURL: nil)
        webView = nil
        
        if let url = temproraryFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
 }

