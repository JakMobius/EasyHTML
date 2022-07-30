//
//  RecentGitHubItem.swift
//  EasyHTML
//
//  Created by Артем on 26/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubHistory {
    enum Entry: Codable, Equatable {

        enum CodingKeys: CodingKey {
            case type
            case value
            case displayName
            case id
        }

        static public func ==(lhs: Entry, rhs: Entry) -> Bool {
            switch (lhs, rhs) {
            case let (.searched(a), .searched(b)):
                return a == b
            case let (.visitedRepo(a), .visitedRepo(b)):
                return a == b
            case let (.visitedUser(a, b), .visitedUser(c, d)):
                return a == c && b == d
            default:
                return false
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let type = try container.decode(Int.self, forKey: .type)
            let value = try container.decode(String.self, forKey: .value)

            switch type {
            case 0:
                self = .searched(name: value)
            case 1:
                let displayName = try container.decode(String.self, forKey: .displayName)
                self = .visitedRepo(name: displayName)
            default: // case 2:
                let id = try container.decode(Int.self, forKey: .id)
                self = .visitedUser(nick: value, id: id)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .searched(let name):
                try container.encode(0, forKey: .type)
                try container.encode(name, forKey: .value)
                break
            case .visitedRepo(let name):
                try container.encode(1, forKey: .type)
                try container.encode("", forKey: .value)
                try container.encode(name, forKey: .displayName)
                break
            case .visitedUser(let nick, let id):
                try container.encode(2, forKey: .type)
                try container.encode(nick, forKey: .value)
                try container.encode(id, forKey: .id)
                break
            }
        }

        case searched(name: String)
        case visitedRepo(name: String)
        case visitedUser(nick: String, id: Int)
    }
}
