//
//  DropboxFile.swift
//  EasyHTML
//
//  Created by Артем on 02/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation
import SwiftyDropbox

internal class DropboxFile: FSNode.File {
    override internal var size: Int64 {
        get {
            Int64(metadata.size)
        }
    }

    internal var metadata: Files.FileMetadata!

    private override init(url: URL) {
        fatalError()
    }

    internal init(url: URL, metadata: Files.FileMetadata) {
        self.metadata = metadata
        super.init(url: url)
        sourceType = .dropbox
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    internal override func isEqual(_ object: Any?) -> Bool {
        if let file = object as? DropboxFile {
            return file.metadata.id == metadata.id
        }
        return false
    }
}

internal class DropboxFolder: FSNode.Folder {
    override internal var countOfFilesInside: Int {
        get {
            _countOfFilesInside
        }
    }

    private var _countOfFilesInside = -1

    private var anyRequest: Any?

    internal func stopNetworkActivity() {
        if let request = anyRequest as? RpcRequest<Files.ListFolderResultSerializer, Files.ListFolderErrorSerializer> {
            request.cancel()
        } else if let request = anyRequest as? RpcRequest<Files.ListFolderResultSerializer, Files.ListFolderContinueErrorSerializer> {
            request.cancel()
        }
        anyRequest = nil
    }

    internal func getCountOfFilesInsideAsync(completion: @escaping (Bool, Int) -> ()) {
        let client = DropboxClientsManager.authorizedClient!

        var result = 0

        func callback(response: Files.ListFolderResult?, error: CustomStringConvertible?) {
            guard error == nil, let response = response else {
                completion(false, 0)
                return
            }

            result += response.entries.count

            if (response.hasMore) {
                anyRequest = client.files.listFolderContinue(cursor: response.cursor).response(completionHandler: callback)
            } else {
                _countOfFilesInside = result
                completion(true, result)
            }
        }

        anyRequest = client.files.listFolder(path: url.path, recursive: false, includeMediaInfo: false, includeDeleted: false, includeHasExplicitSharedMembers: false, includeMountedFolders: false, limit: 2000).response(completionHandler: callback)
    }

    internal var metadata: Files.FolderMetadata!

    private override init(url: URL) {
        fatalError()
    }

    internal init(url: URL, metadata: Files.FolderMetadata) {
        self.metadata = metadata
        super.init(url: url)
        sourceType = .dropbox
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    internal override func isEqual(_ object: Any?) -> Bool {
        if let folder = object as? DropboxFolder {
            return folder.metadata.id == metadata.id
        }
        return false
    }
}
