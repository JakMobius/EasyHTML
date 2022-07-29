//
//  DropboxIOManager.swift
//  EasyHTML
//
//  Created by Артем on 02/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation
import SwiftyDropbox

internal class DropboxIOManager: Editor.IOManager {
    
    internal override func saveFileAt(url: URL, data: Data, completion: Editor.IOManager.WriteResult) {
        
        let client = DropboxClientsManager.authorizedClient!
        
        client.files.upload(path: url.path, mode: .overwrite, autorename: false, clientModified: nil, mute: false, input: data).response { (metadata, error) in
            
            completion?(DropboxError(error: error?.generalized))
        }
    }
    
    internal override func readFileAt(url: URL, completion: Editor.IOManager.ReadResult, progress: ((Progress) -> ())? = nil) -> CancellableRequest {
        let client = DropboxClientsManager.authorizedClient!
        var request: CancellableRequest!
        var dropboxRequest: DownloadRequestMemory<Files.FileMetadataSerializer, Files.DownloadErrorSerializer>!
        
        dropboxRequest = client.files.download(path: url.path).response {
            file, error in
            if self.requestCompleted(request) {
                if error != nil {
                    completion?(nil, DropboxError(error: error?.generalized))
                } else {
                    completion?(file?.1, nil)
                }
            }
            }.progress { (prog) in
                progress?(prog)
        }
        
        request = CancellableRequest() {
            request in
            dropboxRequest?.cancel()
            self.requestCompleted(request)
        }
        
        requestStarted(request)
        
        return request
    }
}
