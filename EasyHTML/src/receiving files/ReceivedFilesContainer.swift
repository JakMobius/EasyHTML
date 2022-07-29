//
//  ReceivedFilesContainer.swift
//  EasyHTML
//
//  Created by Артем on 13.06.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import Foundation

class ReceivedFilesContainer: SharedFileContainer {
    
    func updateFilesRelocationState(task: FilesRelocationTask) {
        fatalError("Container is read-only")
    }
    
    var fileListManager: FileListManager!
    
    var prefix: String = "received-"
    
    var canReceiveFiles: Bool = false // Контейнер только для чтения
    
    func canReceiveFile(file: FSNode, from source: FileSourceType) -> FilesRelocationManager.FileReceiveability {
        return .no(reason: .unsupportedController)
    }
    
    func receiveFile(file: String, from source: FileSourceType, storedAt atURL: URL, callback: @escaping FilesRelocationCompletion, progress: (Float) -> ()) {
        fatalError("Container is read-only")
    }
    
    func hasRetainedFile(file: FSNode) {
        fatalError("Container is read-only")
    }
    
    func prepareToRelocation(file: FSNode, to destination: FileSourceType, completion: @escaping (URL?, Error?) -> (), progress: (Float) -> ()) {
        
        if let name = overrideFilename {
            completion(url.appendingPathComponent(name), nil)
            return
        }
        
        completion(url.appendingPathComponent(file.name), nil)
        
    }
    
    var overrideFilename: String!
    var url: URL!
    
    var sourceType: FileSourceType = .local
    
    init(url: URL) {
        self.url = url
    }
}
