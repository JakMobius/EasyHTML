//
//  SourceCodeEditorSession.swift
//  EasyHTML
//
//  Created by Артем on 06.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

class SourceCodeEditorSession {
    private typealias SourceCodeEditorSessions = [URL : Weak<SourceCodeEditorSession>]
    private static var storageLocations = [FileSourceType : SourceCodeEditorSessions]()
    
    private static func getStorages(for fileSourceType: FileSourceType) -> SourceCodeEditorSessions {
        let storages = storageLocations[fileSourceType]
        
        if storages == nil {
            let newStorages = SourceCodeEditorSessions()
            storageLocations[fileSourceType] = newStorages
            return newStorages
        }
        
        return storages!
    }
    
    static func get(file: FSNode.File) -> SourceCodeEditorSession {
        let storages = getStorages(for: file.sourceType)
        let storage = storages[file.url]
        
        if storage == nil {
            let newStorage = SourceCodeEditorSession()
            storageLocations[file.sourceType]![file.url] = Weak(value: newStorage)
            
            newStorage.file = file
            
            return newStorage
        }
        
        return storage!.value!
    }
    
    private(set) var file: FSNode.File!
    
    var viewControllers = [UIViewController]()
    var sessionDispatcher: SourceCodeEditorSessionDispatcher! {
        didSet {
            sessionDispatcher.session = self
        }
    }
    
    deinit {
        if let storages = SourceCodeEditorSession.storageLocations[file.sourceType] {
            if storages.count == 1 {
                SourceCodeEditorSession.storageLocations.removeValue(forKey: file.sourceType)
            } else {
                SourceCodeEditorSession.storageLocations[file.sourceType]!.removeValue(forKey: file.url)
            }
        }
    }
}
