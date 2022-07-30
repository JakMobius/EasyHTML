//
//  BootUtils.swift
//  EasyHTML
//
//  Created by Артем on 05.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit


class BootUtils {
    @objc func keyboardAppearance() -> UIKeyboardAppearance {
        (userPreferences.adjustKeyboardAppearance && userPreferences.currentTheme.isDark) ? .dark : .light
    }

    static func setupWebViewKeyboardAppearance() {

        let darkImp = class_getMethodImplementation(BootUtils.self, #selector(keyboardAppearance))!

        for classString in ["WKContentView", "UITextInputTraits"] {
            let c: AnyClass = NSClassFromString(classString)!
            let m = class_getInstanceMethod(c, #selector(getter: UITextInputTraits.keyboardAppearance))

            if (m != nil) {
                method_setImplementation(m!, darkImp);
            } else {
                class_addMethod(c, #selector(getter: UITextInputTraits.keyboardAppearance), darkImp, "l@:");
            }
        }
    }

    static func checkSharedFolderExistence() -> URL! {
        guard var containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.JakMobius.EasyHTML") else {
            return nil
        }

        containerUrl.appendPathComponent("Documents")

        return FileManager.default.fileExists(atPath: containerUrl.path, isDirectory: nil) ? containerUrl : nil
    }

    static func initMenuController() {
        let menuController = UIMenuController.shared

        menuController.menuItems = [
            UIMenuItem(title: localize("search", .editor), action: #selector(SwizzledWebView.searchOccurrences)),
            UIMenuItem(title: localize("replace", .editor), action: #selector(SwizzledWebView.replaceOccurrences))
        ]
    }

    static func deleteSharedFolderIfExist() {
        if let url = checkSharedFolderExistence() {

            let path = FileBrowser.filesFullPath
            let name = FileBrowser.getAvailableFileName(fileName: "\(localize("sharedfoldername")) (old)", path: path)

            try? FileManager.default.moveItem(atPath: url.path, toPath: path + name)
        }
    }

    static var isFirstLaunch: Bool = !isDir(fileName: applicationPath + FileBrowser.filesDir)
}
