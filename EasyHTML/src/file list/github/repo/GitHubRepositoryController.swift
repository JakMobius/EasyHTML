//
//  GitHubRepositoryController.swift
//  EasyHTML
//
//  Created by Артем on 29/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit
import Alamofire

struct GitHubLanguageItem {
    var language: String
    var fraction: Double
}

/// Класс, получающий информацию о репозитории из JSON-объекта.

fileprivate class JSONRepositoryInfoParser: JSONParser {
    
    var contributors: Int?
    var commits: Int?
    var branches: Int?
    var releases: Int?
    var updateDate: Date?
    var size: Int?
    var defaultBranch: String?
    var license: String?
    var ownerAvatarUrl: String?
    var languages = [GitHubLanguageItem]()
    var description: String?
    var ownerId: Int?
    
    override init(object: Object?) {
        super.init(object: object)
        
        jumpTo(field: "repository")
        
        description =    valueByKey(key: ["description"], value: String.self)
        releases =       valueByKey(key: ["releases", "totalCount"], value: Int.self)
        contributors =   valueByKey(key: ["mentionableUsers", "totalCount"], value: Int.self)
        commits =        valueByKey(key: ["object", "history", "totalCount"], value: Int.self) ?? 0
        license =        valueByKey(key: ["licenseInfo", "spdxId"], value: String.self)
        defaultBranch =  valueByKey(key: ["defaultBranchRef", "name"], value: String.self)
        ownerAvatarUrl = valueByKey(key: ["owner", "avatarUrl"], value: String.self)
        branches =       valueByKey(key: ["refs", "totalCount"], value: Int.self)
        size =           valueByKey(key: ["diskUsage"], value: Int.self)
        ownerId =        valueByKey(key: ["owner", "databaseId"], value: Int.self)
        
        if let updateDate = valueByKey(key: ["updatedAt"], value: String.self) {
            self.updateDate = GitHubAPI.apiDateFormatter.date(from: updateDate)
        }
        if let languages = valueByKey(key: ["languages", "edges"], value: [Object].self) {
            var totalSize = 0
            
            self.languages.reserveCapacity(languages.count)
            
            for language in languages {
                guard let size = valueByKey(key: ["size"], value: Int.self, object: language) else {
                    continue
                }
                guard let name = valueByKey(key: ["node", "name"], value: String.self, object: language) else {
                    continue
                }
                
                let languageItem = GitHubLanguageItem(language: name, fraction: Double(size))
                
                self.languages.append(languageItem)
                totalSize += size
            }
            
            let multipler = 1 / Double(totalSize)
            
            for i in 0 ..< self.languages.count {
                self.languages[i].fraction *= multipler
            }
        }
    }
}

class GitHubRepositoryController: GitHubPreviewController, SharedFileContainer {
    
    func canReceiveFile(file: FSNode, from source: FileSourceType) -> FilesRelocationManager.FileReceiveability {
        return .no(reason: .unsupportedController)
    }
    
    func receiveFile(file: String, from source: FileSourceType, storedAt atURL: URL, callback: @escaping FilesRelocationCompletion, progress: @escaping (Float) -> ()) {
        fatalError("Container is read-only")
    }
    
    func prepareToRelocation(file: FSNode, to destination: FileSourceType, completion: @escaping (URL?, Error?) -> (), progress: @escaping (Float) -> ()) {
        
        let branch = fetchedRepositoryData.defaultBranch ?? "master"
        
        guard let url = URL(string: "https://github.com/\(repositoryFullName!)/archive/\(branch).zip") else {
            completion(nil, GitHubError.unknown)
            return
        }
        
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            let tempDirPath = NSTemporaryDirectory()
            
            var fileDir: String
            repeat {
                fileDir = tempDirPath + UUID().uuidString
            } while(fileOrFolderExist(name: fileDir))
            
            fileDir += ".zip"
            
            return (URL(fileURLWithPath: fileDir), [.removePreviousFile])
        }
        
        Alamofire.download(
            url,
            method: .get,
            parameters: nil,
            encoding: JSONEncoding.default,
            headers: nil,
            to: destination
        ).responseData { (response) in
            if let error = response.error {
                completion(nil, error)
                return
            }
            guard let url = response.destinationURL else {
                completion(nil, GitHubError.unknown)
                return
            }
            completion(url, nil)
            }.downloadProgress { progress(Float($0.fractionCompleted)) }
        
    }
    
    func hasRetainedFile(file: FSNode) {
        fatalError("Container is read-only")
    }
    
    func updateFilesRelocationState(task: FilesRelocationTask) {
        fatalError("Container is read-only")
    }
    
    var url: URL! = URL(string: "/")!
    
    var sourceType: FileSourceType {
        return .github(repo: repositoryFullName, commit: commitName)
    }
    
    var canReceiveFiles: Bool = false
    
    var prefix: String = "github-"
    
    private var commitName: String {
        get {
            return self.commitID ?? fetchedRepositoryData.defaultBranch ?? "master"
        }
    }
    
    var commitID: String!
    var repositoryFullName: String! {
        didSet {
            prefix = "github-" + repositoryFullName + "-"
        }
    }
    
    private var repositoryOwner: String!
    private var repositoryName: String!
    
    var loadingError: Error!
    
    fileprivate var fetchedRepositoryData: JSONRepositoryInfoParser!
    
    override func updateTheme() {
        
        super.updateTheme()
        updateStyle()
        updateToolBar()
        
        if activityIndicator != nil {
            activityIndicator.style = userPreferences.currentTheme.isDark ? .white : .gray
        }
        
        if fetchedRepositoryData.defaultBranch != nil {
            headerCell = nil // Заставим обновиться первую ячейку
            tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return indexPath.row == 1
        }
        if indexPath.section == 1 {
            return indexPath.row == 0
        }
        
        return false
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            if indexPath.row == 1 {
                if let cell = tableView.cellForRow(at: indexPath) as? StatisticCell {
                    cell.toggleLanguages()
                }
            }
        }
        
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                let controller = GitHubFileListController()
                
                controller.fileListManager = self.fileListManager
                controller.commitID = self.commitName
                controller.repositoryFullName = self.repositoryFullName
                
                navigationController!.pushViewController(controller, animated: true)
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func fetchInfo() {
        
        removeErrorLabel()
        
        let query = """
            query repository($owner: String!, $repo: String!) {
                repository(owner: $owner, name: $repo) {
                    updatedAt
                    diskUsage
                    description
                    languages(first: 50, orderBy: {field: SIZE, direction: DESC}) {
                        edges {
                            node {
                                name
                            }
                            size
                        }
                    }
                    releases {
                        totalCount
                    }
                    licenseInfo {
                        spdxId
                    }
                    mentionableUsers {
                        totalCount
                    }
                    defaultBranchRef {
                        name
                    }
                    owner {
                        avatarUrl
                        ... on Organization {
                            databaseId
                        }
                        ... on User {
                            databaseId
                        }
                    }
                    refs(refPrefix: "refs/heads/") {
                        totalCount
                    }
                    object(expression:"master") {
                        ... on Commit {
                            history {
                                totalCount
                            }
                        }
                    }
                }
            }
        """
        
        self.queryRequest = GitHubAPI.enqueueQuery(query: query, arguments: [
            "owner": repositoryOwner,
            "repo": repositoryName
        ]) { (result, error) in
            
            self.headerCell = nil
            self.statisticCell = nil
            self.readMeCell = nil
            
            self.activityIndicator?.removeFromSuperview()
            self.activityIndicator = nil
            self.refresh.endRefreshing()
            
            guard let result = result else {
                self.showErrorLabel(text: error!.localizedDescription)
                return
            }
            
            self.fetchedRepositoryData = JSONRepositoryInfoParser(object: result)
            self.tableView.reloadData()
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let fractions = repositoryFullName.split(separator: "/")
        
        self.repositoryOwner = String(fractions[0])
        self.repositoryName = String(fractions[1])
        
        title = self.repositoryName
        
        tableView.register(HeaderCell.self, forCellReuseIdentifier: "header")
        tableView.register(StatisticCell.self, forCellReuseIdentifier: "statistic")
        tableView.register(ReadMeCell.self, forCellReuseIdentifier: "readme")
        tableView.register(ViewCodeCell.self, forCellReuseIdentifier: "viewcode")
        
        refreshData()
    }
    
    @objc override func refreshData() {
        queryRequest?.cancel()
        fetchInfo()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                return UITableView.automaticDimension
            } else {
                return 60
            }
        } else if indexPath.section == 1 {
            return 40
        } else if indexPath.section == 2 {
            return readMeCell?.height ?? 50
        }
        
        return 50
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        if fetchedRepositoryData == nil {
            return 0
        }
        
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            return 2
        }
        if section == 1 {
            return 1
        }
        if section == 2 {
            return 1
        }
        
        return 0
    }
    
    func refreshStatistics() {
        guard statisticCell != nil else { return }
        let views = statisticCell.statisticStackViews
        
        func format(_ value: Int?) -> String {
            if(value == nil) {
                return "..."
            }
            return String(value!)
        }
        
        let commits = format(fetchedRepositoryData.commits)
        let branches = format(fetchedRepositoryData.branches)
        let releases = format(fetchedRepositoryData.releases)
        let contributors = format(fetchedRepositoryData.contributors)
        var license = fetchedRepositoryData.license ?? "None"
        
        if license == "NOASSERTION" {
            license = "Custom"
        }
        
        views[0].label.text = commits
        views[1].label.text = branches
        views[2].label.text = releases
        views[3].label.text = contributors
        views[4].label.text = license
    }
    
    var headerCell: GitHubRepositoryController.HeaderCell!
    var statisticCell: StatisticCell!
    var readMeCell: ReadMeCell!
    var viewCodeCell: ViewCodeCell!
    
    func getURL() -> URL? {
        return URL(string: "https://github.com/" + self.repositoryFullName)
    }
    
    func shareRepo(view: UIView) {
        guard let url = getURL() else { return }
        
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        activityViewController.popoverPresentationController?.sourceView = view
        activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 44, height: 38)
        
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    func openInSafari(action: UIAlertAction) {
        guard let url = getURL() else { return }
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }
    
    func cloneRepo(action: UIAlertAction) {
        let file = GitHubFile(url: URL(string: "/" + repositoryName + ".zip")!, sourceType: self.sourceType, sha: "")
        
        fileListManager.startMovingFiles(cells: nil, files: [file], from: self)
    }
    
    func goToOwner(action: UIAlertAction) {
        GitHubHistory.push(item: .visitedUser(nick: repositoryOwner, id: fetchedRepositoryData.ownerId!))
        
        let controller = GitHubUserController()
        controller.userName = repositoryOwner
        controller.fileListManager = fileListManager
        
        navigationController?.pushViewController(controller, animated: true)
    }
    
    @objc func moreButtonTapped(_ sender: UIButton) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: localize("share"), style: .default , handler: {
            _ in
            self.shareRepo(view: sender)
        }))
        controller.addAction(UIAlertAction(title: localize("openinsafari", .github), style: .default, handler: openInSafari(action:)))
        controller.addAction(UIAlertAction(title: localize("clonerepo", .github), style: .default, handler: cloneRepo))
        controller.addAction(UIAlertAction(title: localize(repositoryOwner, .github), style: .default, handler: goToOwner))
        controller.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler:nil))
        
        controller.popoverPresentationController?.sourceView = sender
        controller.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 44, height: 38)
        
        self.present(controller, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                if headerCell != nil {
                    return headerCell
                }
                
                headerCell = (tableView.dequeueReusableCell(withIdentifier: "header", for: indexPath) as! HeaderCell)
                
                let avatar = fetchedRepositoryData.ownerAvatarUrl
                
                headerCell.loadAvatar(link: avatar, nick: repositoryOwner)
                
                let attributedString = NSMutableAttributedString()
                
                let color: UIColor
                
                if userPreferences.currentTheme.isDark {
                    color = GitHubUtils.tintDarkColor
                } else {
                    color = GitHubUtils.tintLightColor
                }
                
                attributedString.append(NSAttributedString(
                    string: self.repositoryOwner,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                        .foregroundColor: color
                    ]
                ))
                
                attributedString.append(NSAttributedString(
                    string: " / ",
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                        .foregroundColor: userPreferences.currentTheme.secondaryTextColor
                    ]
                ))
                
                attributedString.append(NSAttributedString(
                    string: self.repositoryName,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                        .foregroundColor: color
                    ]
                ))
                
                headerCell.repoName.attributedText = attributedString
                
                
                
                if headerCell.moreActionsButton.actions(forTarget: self, forControlEvent: UIControl.Event.touchUpInside)?.isEmpty ?? true {
                    headerCell.moreActionsButton.addTarget(self, action: #selector(moreButtonTapped), for: .touchUpInside)
                }
                
                let date = GitHubUtils.dateFormatter.string(from: fetchedRepositoryData.updateDate!)
                let size = getLocalizedFileSize(bytes: Int64(fetchedRepositoryData.size! * 1024), fraction: 2, shouldCheckAdditionalCases: false)
                
                let updateDateAndLicense = "\(localize("repolastupdate", .github)) \(date) • \(size)"
                
                headerCell.descriptionLabel.text = fetchedRepositoryData.description
                headerCell.updateDate.text = updateDateAndLicense
                
                return headerCell
            } else if indexPath.row == 1 {
                if statisticCell != nil {
                    return statisticCell
                }
                
                statisticCell = (tableView.dequeueReusableCell(withIdentifier: "statistic", for: indexPath) as? StatisticCell)
                
                statisticCell.setLanguages(languages: fetchedRepositoryData!.languages)
                
                self.refreshStatistics()
                
                return statisticCell
            }
        } else if indexPath.section == 1 {
            if viewCodeCell != nil {
                return viewCodeCell
            }
            
            viewCodeCell = tableView.dequeueReusableCell(withIdentifier: "viewcode", for: indexPath) as? ViewCodeCell
            viewCodeCell.userNick.text = localize("viewcode", .github)
            viewCodeCell.accessoryType = .disclosureIndicator
            
            return viewCodeCell
        } else if indexPath.section == 2 {
            if readMeCell != nil {
                return readMeCell
            }
            
            readMeCell = (tableView.dequeueReusableCell(withIdentifier: "readme", for: indexPath) as! ReadMeCell)
            
            readMeCell.repoName = repositoryFullName
            readMeCell.branchName = fetchedRepositoryData.defaultBranch ?? "master"
            
            readMeCell.loadFile()
            
            return readMeCell
        }
        
        return UITableViewCell()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
         guard let cell = self.readMeCell else { return }
        
        // Сразу ширина ячейки не обновляется, и вызывать cell.updateHeight
        // бессмысленно.
        
        DispatchQueue.main.async(execute: cell.fetchHeight)
    }
}
