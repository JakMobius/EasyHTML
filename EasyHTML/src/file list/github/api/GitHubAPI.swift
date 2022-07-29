//
//  GitHubAPI.swift
//  EasyHTML
//
//  Created by Артем on 13.07.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit
import SwiftyDropbox

class GitHubAPI {
    static private let service = "jakmobius.easyhtml.github"
    static private let accessTokenKey = "github-accesstoken"
    static private let authURL =         URL(string: "https://github.com/login/oauth/authorize")!
    static private let codeExchangeURL = URL(string: "https://github.com/login/oauth/access_token")!
    static private let qlURL = URL(string: "https://api.github.com/graphql")!
    static let oAuthResultScheme = "easyhtml-15mna7zjbn"
    static private(set) var state: String!
    
    static let clientId = "<application client id>"
    static var clientSecret = "<application client secret>"
    
    static var accessToken: String! = {
        return KeychainService.loadPassword(service: service, account: accessTokenKey)
    }() {
        didSet {
            KeychainService.removePassword(service: service, account: accessTokenKey)
            KeychainService.savePassword(service: service, account: accessTokenKey, data: accessToken)
            
            // Если мы стали готовы к работе
            
            if(oldValue == nil && accessToken != nil && !queryQueue.isEmpty) {
                processNextQueueEntry()
            }
        }
    }
    
    static var accessCode: String!
    
    /// Отражает, разрешил ли пользователь доступ к своему аккаунту.
    
    static var authorized: Bool {
        return
            accessToken != nil || accessCode != nil
    }
    
    /// Отражает, готов ли API к работе.
    
    static var ready: Bool {
        return
            accessToken != nil
    }
    
    struct OAuthError: LocalizedError {
        private var description: String
        init(description: String) {
            self.description = description
        }
        
        var localizedDescription: String {
            return description
        }
        var errorDescription: String? {
            return description
        }
    }
    
    struct QueryError: LocalizedError {
        private var message: String
        init(message: String) {
            self.message = message
        }
        
        var localizedDescription: String {
            return message
        }
        var errorDescription: String? {
            return message
        }
    }
    
    static private func errorOccured(error: Error) {
        for entry in queryQueue {
            entry.callback(nil, error)
        }
    }
    
    static func fetchAccessCode() {
        
        var request = URLRequest(url: codeExchangeURL)
        request.httpMethod = "POST"
        
        let query = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": accessCode,
            "state": state
        ]
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        request.httpBody = try! JSONSerialization.data(withJSONObject: query, options: [])
        
        URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            if let error = error {
                self.errorOccured(error: error)
            } else {
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data!, options: []) as? [String : Any] else {
                        self.errorOccured(error: OAuthError(description: localize("unknownerror")))
                        return
                    }
                    
                    let error = json["error"]
                    guard error == nil else {
                        self.errorOccured(
                            error: OAuthError(
                                description: (error as? String) ?? localize("unknownerror")
                            )
                        )
                        return
                    }
                    
                    guard let accessCode = json["access_token"] as? String else {
                        self.errorOccured(error: OAuthError(description: localize("unknownerror")))
                        return
                    }
                    
                    self.accessToken = accessCode
                } catch {
                    self.errorOccured(error: OAuthError(description: error.localizedDescription))
                }
            }
        }).resume()
    }
    
    private static var authorizationController: MobileSafariViewController!
    private static var authorizationCancelHandler: (() -> ())? = nil
    
    static var isAuthorizing: Bool {
        return authorizationController != nil
    }
    
    static func authorizationFailed() {
        authorizationController?.dismiss(animated: true, completion: nil)
        authorizationCancelHandler?()
    }
    
    static func authorizationSucceeded() {
        authorizationController?.dismiss(animated: true, completion: nil)
        authorizationController = nil
        authorizationCancelHandler = nil
    }
    
    static func authorize(on controller: UIViewController, onCancel: @escaping () -> ()) {
        // Повзаимствуем контроллер у дропбокса, почему бы и нет
        
        var components = URLComponents()
        
        state = UUID().uuidString
        
        let query = [
            "client_id": clientId,
            "scope": "user repo read:org",
            "state": state
        ].map { URLQueryItem(name: $0.key, value: $0.value) }
        
        components.host = "github.com"
        components.scheme = "https"
        components.path = "/login/oauth/authorize"
        components.queryItems = query
        
        let handler = {
            authorizationController = nil
            authorizationCancelHandler = nil
            onCancel()
        }
        
        let safari = MobileSafariViewController(url: components.url!, cancelHandler: handler)
        
        authorizationCancelHandler = handler
        
        controller.present(safari, animated: true, completion: nil)
        
        authorizationController = safari
    }
    
    typealias JSONObject = [String : Any]
    
    struct QueueEntry {
        fileprivate var query: String
        fileprivate var callback: (JSONObject?, Error?) -> ()
        fileprivate var arguments: [String : String?]!
        fileprivate var request: URLSessionTask!
        fileprivate var cancelled: Bool = false
        
        public mutating func cancel() {
            cancelled = true
            request?.cancel()
        }
    }
    
    private static var queryQueue: [QueueEntry] = []
    private static var waitingRequest = false
    
    private static func processNextQueueEntry() {
        var entry: QueueEntry
        
        repeat {
            entry = queryQueue.removeFirst()
        } while(entry.cancelled)
        
        var request = URLRequest(url: qlURL)
        
        var query: JSONObject = [
            "query": entry.query
        ]
        
        if(entry.arguments != nil) {
            query["variables"] = entry.arguments
        }
        
        request.httpMethod = "POST"
        request.setValue("bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        request.httpBody = try! JSONSerialization.data(withJSONObject: query, options: [])
        
//        print(String(data: request.httpBody!, encoding: .utf8))
        
        waitingRequest = true
        
        entry.request = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            DispatchQueue.main.async {
                self.waitingRequest = false
                
                if let error = error {
                    if (error as NSError).code == NSURLErrorCancelled {
                        return
                    } else {
                        entry.callback(nil, error)
                        return
                    }
                }
                
                if let error = GitHubUtils.checkAPIResponse(response: response as! HTTPURLResponse) {
                    entry.callback(nil, error)
                    return
                }
                
                guard let data = data else {
                    entry.callback(nil, GitHubError.unknown)
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? JSONObject {
                    if let data = json["data"] as? JSONObject {
                        entry.callback(data, nil)
                    } else if let errors = json["errors"] as? [JSONObject] {
                        if let error = errors.first?["message"] as? String {
                            entry.callback(nil, QueryError(message: error))
                        } else {
                            entry.callback(nil, GitHubError.unknown)
                        }
                    } else {
                        let error: GitHubError
                        
                        if let message = json["message"] as? String {
                            error = .message(message: message)
                        } else {
                            error = .unknown
                        }
                        
                        entry.callback(nil, error)
                    }
                } else {
                    entry.callback(nil, GitHubError.unknown)
                }
                
                if !self.queryQueue.isEmpty {
                    self.processNextQueueEntry()
                }
            }
        })
        
        entry.request.resume()
    }
    
    static func enqueueQuery(query: String, arguments: [String : String?]! = nil, callback: @escaping (JSONObject?, Error?) -> ()) -> QueueEntry {
        let entry = QueueEntry(query: query, callback: callback, arguments: arguments)
        
        queryQueue.append(entry)
        
        if(!waitingRequest && ready) {
            processNextQueueEntry()
        }
        
        return entry
    }
    
    static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
        return formatter
    }()
}
