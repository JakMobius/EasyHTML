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

    private var temporaryFileURL: URL! = nil

    override func loadData() {
        loadingInfoView.fade()

        messageManager.reset()

        if file!.url.isFileURL && false {

            let path = NSString(string: applicationPath).deletingLastPathComponent

            webView.loadFileURL(file!.url, allowingReadAccessTo: URL(fileURLWithPath: path))
        } else {

            let tempDirPath = NSTemporaryDirectory()

            var fileDir: String
            repeat {
                fileDir = tempDirPath + UUID().uuidString
            } while (fileOrFolderExist(name: fileDir))

            if !file!.url.pathExtension.isEmpty {
                fileDir += "." + file!.url.pathExtension
            }

            temporaryFileURL = URL(fileURLWithPath: fileDir)

            let loadingInfo = localize("loadingstep_downloading", .editor)

            loadingInfoView.infoLabel.text = loadingInfo.replacingOccurrences(of: "#", with: "0")

            ioManager.readFileAt(url: file!.url, completion: {
                (data, error) in
                self.loadingInfoView.hide()
                self.webView.isHidden = false
                if let data = data {
                    try? data.write(to: self.temporaryFileURL!, options: Data.WritingOptions.atomic)

                    self.webView.loadFileURL(self.temporaryFileURL!, allowingReadAccessTo: URL(fileURLWithPath: tempDirPath))
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

        if let url = temporaryFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

