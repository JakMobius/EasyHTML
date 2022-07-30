//
//  GitHubUserController.swift
//  EasyHTML
//
//  Created by Артем on 08.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

fileprivate class JSONUserParser: JSONParser {
    var name: String!
    var login: String!
    var bio: String!
    var statusText: String!
    var avatarURL: String!
    var repositories: [JSONShortRepositoryParser] = []

    override init(object: Object!) {
        super.init(object: object)

        jumpTo(field: "user")

        login = valueByKey(key: ["login"], value: String.self)
        name = valueByKey(key: ["name"], value: String.self)
        avatarURL = valueByKey(key: ["avatarUrl"], value: String.self)
        statusText = valueByKey(key: ["status", "message"], value: String.self)

        bio = valueByKey(key: ["bio"], value: String.self)
    }
}

fileprivate class JSONRepoListParser: JSONParser {
    var cursor: String?
    var hasNextPage: Bool = false
    var repositories: [JSONShortRepositoryParser] = []

    override init(object: Object!) {
        super.init(object: object)
        append(object: self.object)
    }

    func append(object: Object) {
        self.object = object

        if (valueByKey(key: ["user"], value: Object.self) != nil) {
            jumpTo(field: "user")
            jumpTo(field: "repositories")
        } else {
            jumpTo(field: "organization")
            jumpTo(field: "repositories")
        }

        cursor = valueByKey(key: ["pageInfo", "endCursor"], value: String.self)
        hasNextPage = valueByKey(key: ["pageInfo", "hasNextPage"], value: Bool.self) ?? false

        if let repos = valueByKey(key: ["nodes"], value: [Object].self) {
            repositories.reserveCapacity(repos.count)
            for repo in repos {
                repositories.append(JSONShortRepositoryParser(object: repo))
            }
        }
    }
}

class GitHubUserController: GitHubPreviewController {

    var userName: String!
    fileprivate var fetchedUserInfo: JSONUserParser!
    fileprivate var fetchedReposInfo: JSONRepoListParser!
    fileprivate var continuousListError: String!

    override func updateTheme() {

        super.updateTheme()
        updateToolBar()
        updateStyle()

        if activityIndicator != nil {
            activityIndicator.style = userPreferences.currentTheme.isDark ? .white : .gray
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = userName

        tableView.register(HeaderCell.self, forCellReuseIdentifier: "header")
        tableView.register(GitHubLobby.RepoCell.self, forCellReuseIdentifier: "repo")
        tableView.estimatedRowHeight = 125

        refreshData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {

        if fetchedUserInfo == nil {
            return 0
        }

        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        if section == 1 {
            return fetchedReposInfo?.repositories.count ?? 0
        }

        return 0
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)

        if shouldLoadNextPage {
            nextPage()
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 1) {
            return localize("repos", .github)
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    @objc func moreButtonTapped() {

    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if (indexPath.section == 0) {
            return false
        }
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if (indexPath.section == 1) {
            let repo = fetchedReposInfo!.repositories[indexPath.row]

            GitHubHistory.push(item: .visitedRepo(name: repo.name))

            let controller = GitHubRepositoryController()

            controller.repositoryFullName = repo.name
            controller.fileListManager = fileListManager

            navigationController?.pushViewController(controller, animated: true)
        }
    }

    var headerCell: HeaderCell!

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.section == 0) {
            if headerCell != nil {
                return headerCell
            }

            headerCell = (tableView.dequeueReusableCell(withIdentifier: "header", for: indexPath) as! HeaderCell)

            var name = fetchedUserInfo.name
            let avatar = fetchedUserInfo.avatarURL
            var login = fetchedUserInfo.login

            headerCell.loadAvatar(link: avatar, nick: login)

            if name == nil {
                name = login
                login = nil
            }

            headerCell.userName.text = login
            headerCell.realName.text = name

            if headerCell.moreActionsButton.actions(forTarget: self, forControlEvent: UIControl.Event.touchUpInside)?.isEmpty ?? true {
                headerCell.moreActionsButton.addTarget(self, action: #selector(moreButtonTapped), for: .touchUpInside)
            }

            headerCell.bio.text = fetchedUserInfo.bio

            if fetchedUserInfo.bio == nil || fetchedUserInfo.bio.isEmpty {
                headerCell.bioHeightConstraint.isActive = true
            } else {
                headerCell.bioHeightConstraint.isActive = false
            }

            headerCell.statusLabel.text = fetchedUserInfo.statusText

            return headerCell
        } else if (indexPath.section == 1) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "repo", for: indexPath) as! GitHubLobby.RepoCell

            let repo = fetchedReposInfo.repositories[indexPath.row]

            cell.repoTitle.text = repo.name ?? "<unnamed>"
            cell.descField.text = repo.description ?? ""
            cell.setUpdateDateAndLicense(date: repo.updateDate, license: repo.license)
            cell.setLanguage(language: repo.primaryLanguage ?? "")
            cell.setStars(stars: repo.stargazers ?? 0)
            cell.accessoryType = .disclosureIndicator

            return cell
        }

        fatalError()
    }

    override func refreshData() {
        queryRequest?.cancel()
        fetchInfo()
        tableView.reloadData()
    }

    var previousRequestDate: Date!

    func nextPage() {
        if queryRequest != nil {
            return
        }

        previousRequestDate = Date()

        var arguments = [
            "login": userName!
        ]

        if let cursor = fetchedReposInfo?.cursor {
            arguments["cursor"] = cursor
        }

        queryRequest = GitHubAPI.enqueueQuery(query: """
                                                         query repos($login: String!, $cursor: String) {
                                                           user(login: $login) {
                                                             repositories(first: 10, after: $cursor) {
                                                                 pageInfo {
                                                                     hasNextPage
                                                                     endCursor
                                                                 }
                                                                 nodes {
                                                                     nameWithOwner
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
                                                                     updatedAt
                                                                 }
                                                             }
                                                           }
                                                           organization(login: $login) {
                                                             repositories(first: 10, after: $cursor) {
                                                               pageInfo {
                                                                   hasNextPage
                                                                   endCursor
                                                               }
                                                               nodes {
                                                                   nameWithOwner
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
                                                                   updatedAt
                                                               }
                                                             }
                                                           }
                                                         }
                                                     """, arguments: arguments, callback: {
            response, error in

            self.refreshControl?.endRefreshing()
            self.queryRequest = nil
            self.shouldShowActivityIndicatorAtBottom = false

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

            if self.fetchedReposInfo != nil {
                self.fetchedReposInfo.append(object: response)
            } else {
                self.fetchedReposInfo = JSONRepoListParser(object: response)
            }

            self.tableView.reloadData()
        })

        shouldShowActivityIndicatorAtBottom = true
    }

    var shouldLoadNextPage: Bool {

        if queryRequest != nil {
            return false
        }

        if fetchedReposInfo?.cursor == nil {
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
        if section == 1 {
            return continuousListError
        }
        return nil
    }

    func fetchInfo() {

        removeErrorLabel()

        queryRequest = GitHubAPI.enqueueQuery(query: """
                                                         query user($login: String!) {
                                                             user(login: $login) {
                                                                 login
                                                                 name
                                                                 avatarUrl
                                                                 status {
                                                                     message
                                                                 }
                                                                 bio
                                                             }
                                                         }
                                                     """, arguments: [
            "login": userName
        ]) {
            response, error in

            self.fetchedUserInfo = nil
            self.fetchedReposInfo = nil
            self.headerCell = nil
            self.queryRequest = nil
            self.activityIndicator?.removeFromSuperview()
            self.activityIndicator = nil
            self.refresh.endRefreshing()
            self.tableView.reloadData()

            guard let response = response else {
                self.showErrorLabel(text: error!.localizedDescription)
                return
            }

            self.fetchedUserInfo = JSONUserParser(object: response)
            self.nextPage()
        }
    }
}
