//
//  GitHubMoreUsersController.swift
//  EasyHTML
//
//  Created by Артем on 31.10.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

class GitHubMoreUsersController: GitHubPreviewController {
    public var query: String!

    override func viewDidLoad() {
        super.viewDidLoad()
        precondition(query != nil, "Expected query")

        tableView.register(GitHubLobby.UserCell.self, forCellReuseIdentifier: "cell")

        title = localize("more-users", .github).replacingOccurrences(of: "#", with: query)
    }
}
