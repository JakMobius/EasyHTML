//
//  GitHubLobby.swift
//  EasyHTML
//
//  Created by Артем on 26/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

class JSONShortRepositoryParser: JSONParser {
    var name: String!
    var description: String!
    var primaryLanguage: String!
    var stargazers: Int!
    var updateDate: Date!
    var license: String!

    override init(object: Object?) {
        super.init(object: object)

        name = valueByKey(key: ["nameWithOwner"], value: String.self)
        description = valueByKey(key: ["description"], value: String.self)
        primaryLanguage = valueByKey(key: ["primaryLanguage", "name"], value: String.self)
        stargazers = valueByKey(key: ["stargazers", "totalCount"], value: Int.self)
        license = valueByKey(key: ["licenseInfo", "name"], value: String.self)

        if let updateDate = valueByKey(key: ["updatedAt"], value: String.self) {
            self.updateDate = GitHubAPI.apiDateFormatter.date(from: updateDate)
        }
    }
}

fileprivate class JSONSearchResultParser: JSONParser {

    class User: JSONParser {
        var login: String!
        var avatarURL: String!
        var bio: String!
        var id: Int!
        var name: String!

        override init(object: Object?) {
            super.init(object: object)
            login = valueByKey(key: ["login"], value: String.self)
            avatarURL = valueByKey(key: ["avatarUrl"], value: String.self)
            bio = valueByKey(key: ["bio"], value: String.self)
            name = valueByKey(key: ["name"], value: String.self)
            id = valueByKey(key: ["databaseId"], value: Int.self)
        }
    }

    var totalUserCount: Int = 0
    var totalRepoCount: Int = 0
    var hasMoreUsers = false
    var hasMoreRepos = false
    var repositoriesFound: [JSONShortRepositoryParser] = []
    var usersFound: [User] = []

    func fetchUsers(array: [Object]!) {
        guard let array = array else {
            return
        }

        usersFound.reserveCapacity(array.count)

        for object in array {
            let user = User(object: object)

            if (user.login != nil) {
                usersFound.append(user)
            } else {
                totalUserCount -= 1
            }
        }
    }

    func fetchRepositories(array: [Object]!) {
        guard let array = array else {
            return
        }

        repositoriesFound.reserveCapacity(array.count)

        for object in array {
            let repo = JSONShortRepositoryParser(object: object)

            repositoriesFound.append(repo)
        }
    }

    override init(object: Object?) {
        super.init(object: object)

        totalUserCount = valueByKey(key: ["users", "userCount"], value: Int.self) ?? 0
        totalRepoCount = valueByKey(key: ["repos", "repositoryCount"], value: Int.self) ?? 0

        fetchUsers(array: valueByKey(key: ["users", "nodes"], value: [Object].self))
        fetchRepositories(array: valueByKey(key: ["repos", "nodes"], value: [Object].self))

        hasMoreUsers = totalUserCount > 10
        hasMoreRepos = totalRepoCount > 10
    }
}

internal class GitHubLobby: BasicMasterController {

    private var searching: Bool = false
    private var searchText: String = ""

    private var searchResult: JSONSearchResultParser!

    private var searchTask: GitHubAPI.QueueEntry?
    private var updateTimestamp: Date!
    private var searchError: Error!
    private var waitingForUpdate = false

    var fileListManager: FileListManager!

    private var searchCell: SearchCell!

    private var searchItemLimit = 10

    internal override func viewDidLoad() {
        super.viewDidLoad()

        title = "GitHub";

        tableView = UITableView(frame: tableView.frame, style: .grouped)
        tableView.register(SearchCell.self, forCellReuseIdentifier: "search")
        tableView.register(RecentCell.self, forCellReuseIdentifier: "recent")
        tableView.register(UserCell.self, forCellReuseIdentifier: "user")
        tableView.register(RepoCell.self, forCellReuseIdentifier: "repo")
        tableView.register(LabelCell.self, forCellReuseIdentifier: "more")
        tableView.register(SpinnerCell.self, forCellReuseIdentifier: "loading")
        tableView.register(FooterView.self, forHeaderFooterViewReuseIdentifier: "footer")
        tableView.register(NotFoundCell.self, forCellReuseIdentifier: "notfound")

        setupToolBar()
        updateStyle()
        GitHubHistory.readIfNeeded()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()

        setupThemeChangedNotificationHandling()
        tableView.keyboardDismissMode = .interactive

        edgesForExtendedLayout = []
        tableView.estimatedRowHeight = 50
    }

    override func updateTheme() {

        super.updateTheme()
        updateToolBar()
        updateStyle()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return localize("search", .github)
        } else {
            if searching {
                if searchResult == nil {
                    return nil
                }
                if section == 1 {
                    return localize("repos", .github)
                } else {
                    return localize("users", .github)
                }
            } else {
                if GitHubHistory.entries.isEmpty {
                    return nil
                } else {
                    return localize("recentsearches", .github)
                }
            }
        }
    }

    @objc private func searchFieldDidEnter(field: UITextField) {
        guard var text = field.text else {
            return
        }
        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            return
        }

        GitHubHistory.push(item: .searched(name: text))
    }

//    func tableview_debug() {
//        print("TABLEVIEW DEBUG")
//        
//        for i in 0 ..< self.numberOfSections(in: tableView) {
//            print("\(i) = \(self.tableView(tableView, numberOfRowsInSection: i))")
//        }
//        
//        print(" -- ")
//    }

    func setSearchRequest(request: String) {

        searchText = request
        searchCell.field.text = request
        searching = true

        tableView.reloadData()

        refreshResults()
    }

    @objc private func searchFieldUpdated(field: UITextField) {

        searchText = field.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if !searching {
            if !searchText.isEmpty {
                UIView.setAnimationsEnabled(false)
                tableView.beginUpdates()
                searching = true

                tableView.reloadSections(IndexSet(integer: 1), with: .none)
                tableView.insertSections(IndexSet(integer: 2), with: .none)

                setNeedRefresh()
                tableView.endUpdates()
                UIView.setAnimationsEnabled(true)
            }
        } else {
            if searchText.isEmpty {
                searchTask?.cancel()
                searchTask = nil

                UIView.setAnimationsEnabled(false)
                tableView.beginUpdates()
                searching = false
                tableView.deleteSections(IndexSet(integer: 2), with: .none)
                tableView.reloadSections(IndexSet(integer: 1), with: .none)

                searchResult = nil
                tableView.endUpdates()
                UIView.setAnimationsEnabled(true)
            } else {
                setNeedRefresh()
            }
        }
    }

    func refreshSearchResults() {

        UIView.setAnimationsEnabled(false)
        tableView.reloadSections(IndexSet([1, 2]), with: .none)
        UIView.setAnimationsEnabled(true)
    }

    private var appeared = false

    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()

        if (!GitHubAPI.authorized && !appeared) {
            GitHubAPI.authorize(on: UIApplication.shared.keyWindow!.rootViewController!) {
                self.navigationController?.popViewController(animated: true)
            }
        }
        appeared = true
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        if let cell = cell as? SpinnerCell {
            cell.spinner.startAnimating()
        }
    }

    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        // Not implemented in superclass
        // super.tableView(tableView, didEndDisplaying: cell, forRowAt: indexPath)

        if let cell = cell as? SpinnerCell {
            cell.spinner.stopAnimating()
        }

        if let cell = cell as? UserCell {
            cell.cancelAvatarLoading()
            cell.clearAvatar()
        }

        if let cell = cell as? RecentCell {
            cell.cancelAvatarLoading()
            cell.clearAvatar()
        }
    }

    func refreshResults() {

        if !searching {
            return
        }

        searchTask?.cancel()
        searchResult = nil

        searchTask = GitHubAPI.enqueueQuery(query: """
                                                       query search($query: String!) {
                                                           repos: search(first: 10, query: $query, type: REPOSITORY) {
                                                               repositoryCount
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
                                                           users: search(first: 10, query: $query, type: USER) {
                                                               userCount
                                                               nodes {
                                                                   ... on User {
                                                                       login
                                                                       databaseId
                                                                       bio
                                                                       avatarUrl
                                                                       name
                                                                   }
                                                                   ... on Organization {
                                                                       login
                                                                       databaseId
                                                                       avatarUrl
                                                                       name
                                                                   }
                                                               }
                                                           }
                                                       }
                                                   """, arguments: [
            "query": searchCell.field.text!
        ]) {
            response, error in

            if let response = response {
                self.searchResult = JSONSearchResultParser(object: response)
            } else {
                self.searchError = error
            }

            self.searchTask = nil
            self.refreshSearchResults()
        }

        refreshSearchResults()
    }

    func setNeedRefresh() {
        waitingForUpdate = true
        let localTimestamp = Date()
        updateTimestamp = localTimestamp

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: {
            guard self.updateTimestamp == localTimestamp else {
                return
            }

            self.waitingForUpdate = false

            self.refreshResults()
        })
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if searching {
            return CGFloat(searchItemLimit)
        }

        return section == 1 ? 150 : CGFloat(searchItemLimit)
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        50
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 50
        }

        if !searching && indexPath.section == 1 {
            return 50
        }

        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {

        if searching {
            return nil
        }

        if section == 1 {
            if GitHubHistory.entries.isEmpty {
                return tableView.dequeueReusableHeaderFooterView(withIdentifier: "footer")
            } else {
                return nil
            }
        }

        return nil
    }

    internal override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if indexPath.section == 1 && !searching {
                GitHubHistory.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .left)

                if GitHubHistory.entries.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        tableView.reloadSections(IndexSet(integer: 1), with: .fade)
                    }
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if !searching && indexPath.section == 1 {
            return true
        }
        return false
    }

    internal override func numberOfSections(in tableView: UITableView) -> Int {
        searching ? 3 : 2
    }

    internal override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }

        if searching {
            if section == 1 {
                // Reserve a cell for an activity indicator

                if searchResult == nil || waitingForUpdate {
                    return 1
                }

                if searchTask == nil {
                    // Single cell for 'No repositories' text

                    if searchResult.totalRepoCount == 0 {
                        return 1
                    }

                    // Single cell for 'x repositories more' text

                    if searchResult.hasMoreRepos {
                        return searchResult.usersFound.count + 1
                    }
                    return searchResult.repositoriesFound.count
                } else {
                    return 1
                }
            } else {

                // When activity indicator is shown, there should be only one section

                if searchResult == nil || waitingForUpdate {
                    return 0
                }

                if searchTask == nil {

                    // Analogical

                    if searchResult.totalUserCount == 0 {
                        return 1
                    }
                    if searchResult.hasMoreUsers {
                        return searchResult.usersFound.count + 1
                    }
                    return searchResult.usersFound.count
                } else {
                    return 0
                }
            }
        }

        if section == 1 {
            return GitHubHistory.entries.count
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return false
        }

        if indexPath.section == 1 {
            if searching {
                if searchError != nil {
                    return false
                }
                return !searchResult.repositoriesFound.isEmpty
            }

            return true
        }
        if indexPath.section == 2 {
            if searching {
                return !searchResult.usersFound.isEmpty
            }

            return false
        }

        return false
    }

    internal override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if searching {
            if indexPath.section == 1 {
                if searchResult.repositoriesFound.isEmpty {
                    return
                }

                if indexPath.row == searchResult.repositoriesFound.count {
                    let controller = GitHubMoreReposController()

                    controller.query = searchText
                    controller.fileListManager = fileListManager
                    navigationController?.pushViewController(controller, animated: true)
                } else {
                    let repo = searchResult.repositoriesFound[indexPath.row]

                    guard let name = repo.name else {
                        return
                    }

                    navigateToRepo(name: name)
                }

            } else if indexPath.section == 2 {
                if searchResult.usersFound.isEmpty {
                    return
                }

                if indexPath.row == searchResult.usersFound.count {
                    let controller = GitHubMoreUsersController()

                    controller.query = searchText
                    controller.fileListManager = fileListManager
                    navigationController?.pushViewController(controller, animated: true)
                } else {
                    let user = searchResult.usersFound[indexPath.row]

                    guard let login = user.login else {
                        return
                    }
                    guard let id = user.id else {
                        return
                    }

                    navigateToUser(nick: login, id: id)
                }
            }
        } else {
            if indexPath.section == 1 {
                let recentItem = GitHubHistory.entries[indexPath.row]

                switch recentItem {
                case .searched(let request):
                    guard searchCell != nil else {
                        return
                    }

                    tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .middle, animated: true)
                    setSearchRequest(request: request)
                case .visitedRepo(let name):
                    navigateToRepo(name: name)
                case .visitedUser(let nick, let id):
                    navigateToUser(nick: nick, id: id)
                }
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }


    func navigateToRepo(name: String) {

        GitHubHistory.push(item: .visitedRepo(name: name))

        let controller = GitHubRepositoryController()

        controller.repositoryFullName = name
        controller.fileListManager = fileListManager

        navigationController?.pushViewController(controller, animated: true)
    }

    func navigateToUser(nick: String, id: Int) {

        GitHubHistory.push(item: .visitedUser(nick: nick, id: id))

        let controller = GitHubUserController()
        controller.userName = nick
        controller.fileListManager = fileListManager

        navigationController?.pushViewController(controller, animated: true)
    }

    internal override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if searchCell != nil {
                return searchCell
            }

            searchCell = (tableView.dequeueReusableCell(withIdentifier: "search", for: indexPath) as! SearchCell)

            searchCell.field.addTarget(self, action: #selector(searchFieldUpdated(field:)), for: .editingChanged)
            searchCell.field.addTarget(self, action: #selector(searchFieldDidEnter(field:)), for: .editingDidEnd)

            return searchCell
        } else if indexPath.section == 1 {
            if searching {
                if !waitingForUpdate && searchTask == nil {
                    if indexPath.row == searchItemLimit {
                        let cell = tableView.dequeueReusableCell(withIdentifier: "more", for: indexPath) as! LabelCell

                        cell.label.textColor = userPreferences.currentTheme.cellTextColor
                        cell.label.text = localize("more", .github).replacingOccurrences(of: "#", with: String(searchResult.totalRepoCount - searchItemLimit))
                        cell.accessoryType = .disclosureIndicator

                        return cell
                    }
                    if searchResult == nil || searchResult.repositoriesFound.isEmpty {
                        let cell = tableView.dequeueReusableCell(withIdentifier: "notfound", for: indexPath) as! NotFoundCell

                        if searchError != nil {
                            cell.label.text = localize(searchError!.localizedDescription, .github)
                        } else {
                            cell.label.text = localize("notfoundrepos", .github)
                        }

                        return cell
                    }
                    let cell = tableView.dequeueReusableCell(withIdentifier: "repo", for: indexPath) as! RepoCell

                    let repo = searchResult.repositoriesFound[indexPath.row]

                    cell.repoTitle.text = repo.name ?? "<unnamed>"
                    cell.descField.text = repo.description ?? ""
                    cell.setUpdateDateAndLicense(date: repo.updateDate, license: repo.license)
                    cell.setLanguage(language: repo.primaryLanguage ?? "")
                    cell.setStars(stars: repo.stargazers ?? 0)
                    cell.accessoryType = .disclosureIndicator

                    return cell
                } else {
                    return tableView.dequeueReusableCell(withIdentifier: "loading", for: indexPath)
                }
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "recent", for: indexPath) as! RecentCell

                cell.observingItem = GitHubHistory.entries[indexPath.row]

                return cell
            }
        } else {
            if !waitingForUpdate && searchTask == nil {
                if indexPath.row == searchItemLimit {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "more", for: indexPath) as! LabelCell

                    cell.label.textColor = userPreferences.currentTheme.cellTextColor
                    cell.label.text = localize("more", .github).replacingOccurrences(of: "#", with: String(searchResult.totalUserCount - searchItemLimit))
                    cell.accessoryType = .disclosureIndicator

                    return cell
                }
                if searchResult.usersFound.isEmpty {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "notfound", for: indexPath) as! NotFoundCell

                    cell.label.text = localize("notfoundusers", .github)

                    return cell
                }
                let cell = tableView.dequeueReusableCell(withIdentifier: "user", for: indexPath) as! UserCell

                let user = searchResult.usersFound[indexPath.row]

                let string = NSMutableAttributedString()

                string.append(NSAttributedString(
                        string: "\(user.login!)  ",
                        attributes: [
                            .font: UserCell.nickFont,
                            .foregroundColor: GitHubUtils.currentTintColor
                        ]
                ))
                if let name = user.name {
                    string.append(NSAttributedString(
                            string: name,
                            attributes: [
                                .font: UserCell.nameFont,
                                .foregroundColor: userPreferences.currentTheme.secondaryTextColor
                            ]
                    ))
                }

                cell.userNick.attributedText = string
                cell.loadAvatar(link: user.avatarURL, nick: user.login)
                cell.accessoryType = .disclosureIndicator
                cell.bioLabel.text = user.bio

                if user.bio == nil || user.bio.isEmpty {
                    cell.regularUsernameConstraint.isActive = false
                    cell.bioLessUsernameConstraint.isActive = true
                } else {
                    cell.regularUsernameConstraint.isActive = true
                    cell.bioLessUsernameConstraint.isActive = false
                }

                return cell
            } else {
                return tableView.dequeueReusableCell(withIdentifier: "loading", for: indexPath)
            }
        }

    }

    override func didReceiveMemoryWarning() {
        GitHubUtils.userImageCache.removeAll()
    }

    deinit {
        clearNotificationHandling()
    }
}

