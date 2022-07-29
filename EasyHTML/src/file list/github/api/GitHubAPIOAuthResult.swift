//
//  GitHubAPIOAuthResult.swift
//  EasyHTML
//
//  Created by Артем on 13.07.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

extension GitHubAPI {

    static func handleRedirectURL(_ url: URL) -> Bool? {
        // Check if this request should be handled by this
        // function

        if url.scheme != oAuthResultScheme {
            return nil
        }

        // Parse query string

        var components = URLComponents()
        components.query = url.query
        var query = [String: String]()

        guard let queryItems = components.queryItems else {
            return false
        }

        for entry in queryItems where entry.value != nil {
            query[entry.name] = entry.value
        }

        if (query["state"] != state) {
            return false
        }

        guard let code = query["code"] else {
            return false
        }

        accessCode = code

        fetchAccessCode()

        return true
    }
}
