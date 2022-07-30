//
//  AdditionalFileMetadata.swift
//  EasyHTML
//
//  Created by Артем on 22.04.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit
import Foundation

internal class TemporaryFileMetadataManager {

    internal static func getFileMetadata(file: FSNode) -> NSMutableDictionary? {
        if let source = sources[file.sourceType] {
            return source[file.url]
        }
        return nil
    }

    internal static func clearMetadata(forFile file: FSNode) {
        if var source = sources[file.sourceType] {
            source.removeValue(forKey: file.url)
        }
    }

    internal static func setFileMetadata(file: FSNode, metadata: NSMutableDictionary) {
        if var source = sources[file.sourceType] {
            source[file.url] = metadata
        } else {
            sources[file.sourceType] = [file.url: metadata]
        }
    }

    internal static func clearJunkMetadataForFile(file: FSNode) {
        if !file.hasMetadata {
            return
        }

        if file.cachedMetadata!.count == 0 {
            if var source = sources[file.sourceType] {
                source.removeValue(forKey: file.url)
            }
        }
    }

    internal static func clearJunkMetadataForFiles(files: [FSNode]) {
        for file in files {
            clearJunkMetadataForFile(file: file)
        }
    }

    typealias FileMetadataStorage = [URL: NSMutableDictionary]

    private static var sources: [FileSourceType: FileMetadataStorage] = [:]
    private static var metadata: FileMetadataStorage = [:]
}
