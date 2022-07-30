//
//  GitHubHistory.swift
//  EasyHTML
//
//  Created by Артем on 31.08.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

class GitHubHistory {
    private static var limit = 30
    private static var loaded = false

    private(set) static var entries: [Entry] = []

    public static func push(item: Entry) {

        entries.removeAll { oldItem -> Bool in
            oldItem == item
        }

        entries.insert(item, at: 0)

        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }

        save()
    }

    public static func remove(at index: Int) {
        entries.remove(at: index)
        save()
    }

    private static func save() {
        guard let data = try? PropertyListEncoder().encode(entries) else {
            return
        }

        Defaults.set(data, forKey: DKey.githubRecent)
    }

    public static func readIfNeeded() {
        guard !loaded else {
            return
        }
        loaded = true

        let data = Defaults.data(forKey: DKey.githubRecent)

        if data != nil, let decoded = try? PropertyListDecoder().decode([Entry].self, from: data!) {
            entries = decoded
        } else {
            entries = []
        }
    }
}
