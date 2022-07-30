//
//  GitHubMoreReposController.swift
//  EasyHTML
//
//  Created by Артем on 31.10.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

fileprivate class JSONReposSearchResultParser: JSONParser {

    var repositories: [JSONShortRepositoryParser] = []
    var cursor: String!

    func fetchRepos(array: [Object]!) {
        guard let array = array else {
            return
        }

        repositories.reserveCapacity(array.count)

        for object in array {
            let repo = JSONShortRepositoryParser(object: object)

            repositories.append(repo)
        }
    }

    override init(object: Object?) {
        super.init(object: object)

        append(object: object)
    }

    func append(object: Object?) {
        cursor = valueByKey(key: ["search", "pageInfo", "endCursor"], value: String.self)
        fetchRepos(array: valueByKey(key: ["search", "nodes"], value: [Object].self))
    }
}

class GitHubMoreReposController: GitHubPreviewController {
    public var query: String!
    private var fetchedInfo: JSONReposSearchResultParser!
    fileprivate var continuousListError: String!
    var previousRequestDate: Date!

    override func viewDidLoad() {
        super.viewDidLoad()
        precondition(query != nil, "Expected query")

        tableView.register(GitHubLobby.RepoCell.self, forCellReuseIdentifier: "cell")
        title = localize("more-repos", .github).replacingOccurrences(of: "#", with: query)

        nextPage()

        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()
    }

    override func refreshData() {
        queryRequest?.cancel()
        fetchedInfo = nil
        nextPage()
        tableView.reloadData()
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)

        if shouldLoadNextPage {
            nextPage()
        }
    }

    func nextPage() {
        if queryRequest != nil {
            return
        }

        var arguments = [
            "query": query
        ]

        if let cursor = fetchedInfo?.cursor {
            arguments["cursor"] = cursor
        }

        previousRequestDate = Date()
        queryRequest = GitHubAPI.enqueueQuery(query: """
                                                     query search($query: String!, $cursor: String) {
                                                       search(first: 10, after: $cursor, query: $query, type: REPOSITORY) {
                                                         pageInfo {
                                                           endCursor
                                                         }
                                                         nodes {
                                                           ... on Repository {
                                                             nameWithOwner
                                                             updatedAt
                                                             description
                                                             primaryLanguage {
                                                               name
                                                             }
                                                             stargazers {
                                                               totalCount
                                                             }
                                                             licenseInfo {
                                                               name
                                                             }
                                                           }
                                                         }
                                                       }
                                                     }
                                                     """, arguments: arguments) { (response, error) in
            self.queryRequest = nil
            self.shouldShowActivityIndicatorAtBottom = false
            self.refreshControl?.endRefreshing()

            guard let response = response else {
                if (self.continuousListError != error!.localizedDescription) {
                    self.continuousListError = error!.localizedDescription
                    self.tableView.reloadData()
                }

                DispatchQueue.main.asyncAfter(wallDeadline: .now() + 3) {
                    [weak self] in
                    if let self = self, self.shouldLoadNextPage {
                        self.nextPage()
                    }
                }
                return
            }

            self.continuousListError = nil

            if self.fetchedInfo != nil {
                self.fetchedInfo.append(object: response)
            } else {
                self.fetchedInfo = JSONReposSearchResultParser(object: response)
            }

            self.tableView.reloadData()
        }

        shouldShowActivityIndicatorAtBottom = true
    }

    var shouldLoadNextPage: Bool {

        if queryRequest != nil {
            return false
        }

        if fetchedInfo?.cursor == nil {
            return false
        }

        if previousRequestDate != nil && previousRequestDate.timeIntervalSinceNow > -1 {
            return false
        }

        let offset = tableView.contentOffset.y

        let maxOffset = tableView.contentSize.height - tableView.frame.height

        if offset > maxOffset - 200 {
            return true
        }

        return false
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        continuousListError
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! GitHubLobby.RepoCell

        let repo = fetchedInfo.repositories[indexPath.row]

        cell.repoTitle.text = repo.name ?? "<unnamed>"
        cell.descField.text = repo.description ?? ""
        cell.setUpdateDateAndLicense(date: repo.updateDate, license: repo.license)
        cell.setLanguage(language: repo.primaryLanguage ?? "")
        cell.setStars(stars: repo.stargazers ?? 0)
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fetchedInfo?.repositories.count ?? 0
    }

}

