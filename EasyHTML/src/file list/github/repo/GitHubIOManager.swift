//
//  GitHubIOManager.swift
//  EasyHTML
//
//  Created by Артем on 04/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation
import Alamofire

class GitHubIOManager: Editor.IOManager {
    
    var repositoryName: String!
    
    override func readFileAt(url: URL, completion: Editor.IOManager.ReadResult, progress: ((Progress) -> ())? = nil) -> CancellableRequest! {
        
        guard let url = URL(string: "https://raw.githubusercontent.com/\(repositoryName!)/master/\(url.path)") else {
            completion?(nil, GitHubError.notFound)
            return nil
        }
        
        let request = Alamofire.request(url)
        
        if progress != nil {
            request.downloadProgress(closure: progress!)
        }
        
        request.response { (response) in
            completion!(response.data, response.error)
        }
        
        return CancellableRequest {
            _ in
            request.cancel()
        }
    }
    
    override func saveFileAt(url: URL, data: Data, completion: Editor.IOManager.WriteResult = nil) {
        completion?(GitHubError.accessDenied)
    }
}
