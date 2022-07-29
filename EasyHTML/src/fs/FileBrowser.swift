//
//  FileBrowser.swift
//  EasyHTML
//
//  Created by Артем on 05.10.17.
//  Copyright © 2017 Артем. All rights reserved.
//

import Foundation
import UIKit

enum SortingType: Int {
    case byLastEditingDate = 0
    case byCreationDate = 1
    case byName = 2
    case byType = 3
    case none = 4
}

class FileBrowser {
    internal static func fileListUpdatedAt(url: URL!) {

        let userInfo: [AnyHashable: Any]? = url == nil ? [:] : ["path": url!]

        NotificationCenter.default.post(name: .TCFileListUpdated, object: nil, userInfo: userInfo)
    }

    internal static func fileMetadataChanged(file: FSNode) {
        NotificationCenter.default.post(name: .TCFileMetadataChanged, object: nil, userInfo: ["file": file])
    }

    internal static func getFullURL(_ url: URL) -> URL {
        URL(fileURLWithPath: getFullPath(url.path))
    }

    internal static func getFullPath(_ path: String) -> String {
        var path = path
        if !path.hasPrefix("/") {
            path = "/" + path
        }

        return filesFullPath + path
    }

    static var filesDir = "/files"
    static var filesFullPath = applicationPath + filesDir

    static func getDir(url: URL) -> [FSNode] {
        var result: [FSNode] = []

        let path = applicationPath + filesDir + url.path
        let fullURL = URL(fileURLWithPath: path)
        let files = listDirWithSorting(path: fullURL.path)

        for file in files {
            if let fsObject = FSNode.getLocalFile(url: url.appendingPathComponent(file)) {
                result.append(fsObject)
            }
        }

        return result
    }

    static func clonedFileName(fileName: String) -> String {
        let fileName = fileName
        let cloneLocalizedString = localize("copyoffile")

        let parts = cloneLocalizedString.split(separator: "#")

        let firstPart = String(parts[0])

        if fileName.starts(with: firstPart) {

            let nameAndExt = getFileNameAndExtensionFromString(fileName: fileName)
            var name = nameAndExt[0]
            var trimmed = false

            repeat {
                let last = name.last
                if let last = last, "0"..."9" ~= last {
                    trimmed = true
                } else {
                    break
                }

                name.removeLast()

            } while true

            if (trimmed && name.last == " ") {
                name.removeLast()
                var fullName = name
                let ext = nameAndExt[1]

                if (!ext.isEmpty) {
                    fullName += "."
                    fullName += ext
                }

                return fullName
            }

            return fileName
            //fileName.removeFirst(firstPart.count)
            //startsWith = true
        } else {
            return cloneLocalizedString.replacingOccurrences(of: "#", with: fileName)
        }

    }

    static func getAvailableFileName(fileName: String, path: String) -> String {

        let files = listDir(dirName: path)
        var ext = ""
        var filename = fileName

        var path = path
        if !path.hasSuffix("/") {
            path += "/"
        }

        if !isDir(fileName: path + fileName) {
            let fileData = getFileNameAndExtensionFromString(fileName: fileName);
            filename = fileData[0]
            ext = fileData[1]
            if (!ext.isEmpty) {
                ext = "." + ext
            }
        }


        let count = files.count

        if (count == 0) {
            return fileName
        }

        var string = filename + ext

        var i = 1
        var flag: Bool

        while true {
            flag = true

            for j in 0..<count where files[j] == string {
                flag = false
                break
            }

            if flag {
                return string
            }

            i += 1

            string = "\(filename) \(i)\(ext)"
        }
    }
}
