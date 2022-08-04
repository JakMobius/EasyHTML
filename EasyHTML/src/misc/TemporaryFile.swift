//
//  TemporaryFile.swift
//  EasyHTML
//
//  Created by Артем on 04.08.2022.
//  Copyright © 2022 Артем. All rights reserved.
//

import Foundation

public extension FileManager {

    func temporaryFileURL(fileName: String = UUID().uuidString) -> URL {
        let tempDirPath = NSTemporaryDirectory()

        var fileName: String
        repeat {
            fileName = tempDirPath + UUID().uuidString
        } while (fileOrFolderExist(name: fileName))
        
        return URL(fileURLWithPath: fileName)
    }
}
