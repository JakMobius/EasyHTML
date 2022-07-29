//
//  GitHubFile.swift
//  EasyHTML
//
//  Created by Артем on 02/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

class GitHubFile: FSNode.File {
    
    override var size: Int64 {
        get {
            return _size
        }
        set {
            _size = newValue
        }
    }
    private var _size: Int64 = -1
    var sha: String!
    
    private override init(url: URL) {
        fatalError() // Не используем этот инициализатор
    }
    
    private override init(url: URL, sourceType: FileSourceType) {
        self.sha = nil
        super.init(url: url)
        self.sourceType = sourceType
    }
    
    internal init(url: URL, sourceType: FileSourceType, sha: String! = nil) {
        self.sha = sha
        super.init(url: url)
        self.sourceType = sourceType
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    internal override func isEqual(_ object: Any?) -> Bool {
        if let file = object as? GitHubFile {
            return file.url == url
        }
        return false
    }
}

class GitHubFolder: FSNode.Folder {
    override internal var countOfFilesInside: Int {
        get {
            return -1
        }
    }
    
    var sha: String!
    
    private override init(url: URL, sourceType: FileSourceType) {
        fatalError() // Не используем этот инициализатор
    }
    
    init(url: URL, sourceType: FileSourceType, sha: String) {
        self.sha = sha
        super.init(url: url, sourceType: sourceType)
    }
    
    required init(from decoder: Decoder) throws {
        self.sha = nil
        try super.init(from: decoder)
    }
    
    internal override func isEqual(_ object: Any?) -> Bool {
        if let folder = object as? FTPFolder {
            return folder.url == url
        }
        return false
    }
    
    internal var modificationDate: Date!
}
