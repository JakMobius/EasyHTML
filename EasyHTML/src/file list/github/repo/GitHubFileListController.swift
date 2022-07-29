//
//  GitHubFileListController.swift
//  EasyHTML
//
//  Created by Артем on 02/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit
import Alamofire

class GitHubFileListController: FileListController, FileListDataSource, FileListDelegate, LibraryPickerDelegate, FileDetailDelegate, FileDetailDataSource {
    
    override var sourceType: FileSourceType {
        return .github(repo: repositoryFullName, commit: commitID)
    }
    
    var commitID: String!
    var repositoryFullName: String!
    var treeID: String!
    
    private var files: [FSNode] = []
    internal var isRoot = true
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        if(repositoryFullName == nil) {
            fatalError("Expected repository name")
        }
        if(url == nil && !isRoot) {
            fatalError("Expected folder path")
        }
        
        fileListDelegate = self
        fileListDataSource = self
        
        if(isRoot) {
            title = commitID
            url = URL(fileURLWithPath: "/")
        }
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: self.title, style: .plain, target: nil, action: nil)
        
        setupFileListUpdatedNotificationHandling()
        NotificationCenter.default.addObserver(self, selector: #selector(fileMetadataDidChange(_:)), name: .TCFileMetadataChanged, object: nil)
        
        isLoading = true
        
        reloadFiles()
    }
    
    @objc internal func fileMetadataDidChange(_ notification: NSNotification) {
        if isCurrentViewController, let userInfo = notification.userInfo, let file = userInfo["file"] as? FSNode {
            
            let folderURL = file.url.deletingLastPathComponent()
            
            if folderURL == self.url, let index = self.files.firstIndex(of: file) {
                let i = self.files.startIndex.distance(to: index)
                
                self.tableView.reloadRows(at: [IndexPath(row: i, section: 0)], with: .none)
            }
        }
    }
    
    var needsUpdate = false
    
    @objc private func fileListUpdated(sender: NSNotification) {
        
        if needsUpdate {
            return
        }
        
        if let userInfo = sender.userInfo {
            
            let path = userInfo["path"] as? URL
            
            if path == nil || path! == self.url {
                if appeared {
                    self.reloadFiles(animated: true)
                } else {
                    needsUpdate = true
                }
            } else if path!.deletingLastPathComponent() == self.url {
                
                var path = path!.path
                
                if path.hasSuffix("/") {
                    path.remove(at: path.endIndex)
                }
                
                for (i, file) in files.enumerated() where file.url.path == path {
                    tableView.reloadRows(at: [IndexPath(row: i, section: 0)], with: .fade)
                }
            }
        }
    }
    
    internal func fileList(selectedFileAt index: Int) {
        
        let file = files[index]
        
        openFile(file: file)
    }
    
    private func fetchCommits() {
        let headers = [
            "page" : "1",
            "per_page" : "1"
        ]
        let url = "https://api.github.com/repos/\(repositoryFullName!)/commits/\(commitID!)"
        Alamofire.request(url, method: .get, encoding: JSONEncoding.default, headers: headers)
            .responseJSON { response in
            
                if let error = response.error {
                    self.showErrorLabel(text: error.localizedDescription)
                    self.isLoading = false
                    self.tableView.reloadData()
                    return
                }
                
                let httpResponse = response.response!
                
                if let error = GitHubUtils.checkAPIResponse(response: httpResponse) {
                    self.isLoading = false
                    self.tableView.reloadData()
                    self.showErrorLabel(text: error.localizedDescription)
                }
                
                if let json = try? response.result.unwrap() as? [String : Any] {
                    if let commit = json["commit"] as? [String : Any] {
                        if let tree = commit["tree"] as? [String : Any] {
                            if let sha = tree["sha"] as? String {
                                self.treeID = sha
                                self.reloadFiles()
                                return
                            }
                        }
                    } else {
                        self.showErrorLabel(text: json["message"] as? String ?? localize("errorunknowm", .github))
                        self.isLoading = false
                        self.tableView.reloadData()
                        return
                    }
                }
                
                self.showErrorLabel(text: localize("errorunkown", .github))
                self.isLoading = false
                self.tableView.reloadData()
                
        }
    }
    
    private func fetchFiles() {
        removeErrorLabel()
        let url = "https://api.github.com/repos/\(repositoryFullName!)/git/trees/\(treeID!)"
        
        self.files = []
        
        Alamofire.request(url, method: .get, encoding: JSONEncoding.default)
            .responseJSON { response in
                
            self.isLoading = false
                
            if let error = response.error {
                self.showErrorLabel(text: error.localizedDescription)
                return
            }
            
            let httpResponse = response.response!
            
            if let error = GitHubUtils.checkAPIResponse(response: httpResponse) {
                self.showErrorLabel(text: error.localizedDescription)
                return
            }
            
            if let json = try? response.result.unwrap() as? [String : Any] {
                if let tree = json["tree"] as? [[String : Any]] {
                    
                    for item in tree {
                        
                        guard let type = item["type"] as? String else { continue }
                        guard let path = item["path"] as? String else { continue }
                        guard let sha = item["sha"] as? String else { continue }
                        
                        let url = self.url.appendingPathComponent(path)
                        
                        if type == "blob" {
                            let file = GitHubFile(url: url, sourceType: self.sourceType, sha: sha)
                            file.size = item["size"] as? Int64 ?? -1
                            self.files.append(file)
                        } else if type == "tree" {
                            self.files.append(GitHubFolder(url: url, sourceType: self.sourceType, sha: sha))
                        }
                    }
                    
                    if self.files.isEmpty {
                        if(!self.emptyFolderWarningShown) {
                            self.showEmptyFolderWarning()
                        }
                    } else {
                        self.hideEmptyFolderWarning()
                    }
                    
                    if self.fileRefreshControl?.isRefreshing == true {
                        self.tableView.reloadData()
                        self.fileRefreshControl.endRefreshing()
                    } else {
                        UIView.transition(with: self.tableView, duration: 0.35, options: .transitionCrossDissolve, animations: {
                            self.tableView.reloadData()
                        })
                    }
                    
                    return
                }
            }
            
            self.showErrorLabel(text: localize("errorunkown", .github))
        }
    }
    
    internal func reloadFiles(animated: Bool = false) {
        self.isLoading = true
        if !(treeID != nil) {
            fetchCommits()
        } else {
            fetchFiles()
        }
    }
    
    private var appeared = false
    
    override func viewDidAppear(_ animated: Bool) {
        appeared = true
        
        reloadFilesIfNeeded()
    }
    
    internal func reloadFilesIfNeeded() {
        if needsUpdate {
            reloadFiles()
            tableView.reloadData()
            needsUpdate = false
        }
    }
    
    override internal func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        reloadFilesIfNeeded()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        appeared = false
    }
    
    internal func countOfFiles() -> Int {
        return files.count
    }
    
    internal func fileList(fileForRowAt index: Int) -> FSNode {
        return files[index]
    }
    
    func navigateToDirectory(_ directory: FSNode.Folder) {
        
        guard let directory = directory as? GitHubFolder else { return }
        
        /*
         Поскольку при копировании файлов контоллеры не удаляются из памяти,
         мы можем оптимизировать память.
         */
        
        if let controller = fileListManager.getCachedController(for: directory.url, with: sourceType) {
            navigationController?.pushViewController(controller, animated: true)
            return
        }
        
        let controller = GitHubFileListController()
        
        controller.fileListManager = fileListManager
        controller.url = url.appendingPathComponent(directory.name)
        controller.treeID = directory.sha
        controller.commitID = self.commitID
        controller.repositoryFullName = self.repositoryFullName
        controller.isRoot = false
        controller.title = directory.name
        
        navigationController?.pushViewController(controller, animated: true)
    }
    
    func openFile(file: FSNode, inNewTab: Bool = false) {
        if(file is FSNode.Folder) {
            navigateToDirectory(file as! FSNode.Folder)
            return
        } else if !fileListManager.isRelocatingFiles {
            let file = file as! FSNode.File
            
            let e = getFileExtensionFromString(fileName: file.name)
            if(e == "zip" || e == "jar") {
                FileListController.presentRemoteUnarchiveWarning(on: view.window!)
                return
            }
            
            let ioManager = GitHubIOManager()
            
            ioManager.repositoryName = self.repositoryFullName
            
            var config: EditorConfiguration = [
                .ioManager : ioManager,
                .isReadonly : true
            ]
            
            if inNewTab {
                config[.openInNewTab] = true
            }
            
            if(Editor.imageExtensions.contains(e)) {
                openAsImage(file: file, config: config)
            } else if(Editor.syntaxHighlightingSchemeFor(ext: e) != nil) {
                openSourceCode(file: file, config: config)
            } else {
                openInBrowser(file: file, config: config)
            }
        }
    }
    
    override func openSourceCode(file: FSNode.File, config: EditorConfiguration? = nil) {
        var config = config
        
        if config == nil {
            config = [:]
        }
        
        config![.isReadonly] = true
        if config![.ioManager] == nil {
            let ioManager = GitHubIOManager()
            
            ioManager.repositoryName = self.repositoryFullName
            
            config![.ioManager] = ioManager
        }
        
        super.openSourceCode(file: file, config: config)
    }
    
    override func openInBrowser(file: FSNode.File, config: EditorConfiguration? = nil, force: Bool = false) {
        var config = config
        
        if config == nil {
            config = [:]
        }
        
        config![.isReadonly] = true
        if config![.ioManager] == nil {
            let ioManager = GitHubIOManager()
            
            ioManager.repositoryName = self.repositoryFullName
            
            config![.ioManager] = ioManager
        }
        
        super.openInBrowser(file: file, config: config, force: force)
    }
    
    override func openAsImage(file: FSNode.File, config: EditorConfiguration? = nil)  {
        var config = config
        
        if config == nil {
            config = [:]
        }
        
        config![.isReadonly] = true
        if config![.ioManager] == nil {
            let ioManager = GitHubIOManager()
            
            ioManager.repositoryName = self.repositoryFullName
            
            config![.ioManager] = ioManager
        }
        
        super.openAsImage(file: file, config: config)
    }
    
    func shareFile(at indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            
            let file = files[indexPath.row]
            let objectsToShare = [file.url]
            let activityController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
            
            let popover = activityController.popoverPresentationController
            
            popover?.sourceView = cell
            popover?.sourceRect = cell.bounds
            
            view.window!.rootViewController!.present(activityController, animated: true, completion: nil)
        }
    }
    
    func shortcutActionsForFile(file: FSNode, at index: Int) -> [ContextMenuAction] {
        let indexPath = IndexPath(row: index, section: 0)
        
        if file is FSNode.Folder {
            return [
                .shareAction {
                    _ in self.shareFile(at: indexPath)
                },
                .moveAction {
                    _ in self.selectFileToRelocate(at: indexPath)
                }
            ]
        } else if let file = file as? FSNode.File {
            
            var actions: [ContextMenuAction] = []
            
            if(file.url.pathExtension != "zip") {
                actions.append(.openInNewTabAction {
                    _ in self.openFile(file: file, inNewTab: true)
                    })
                
                let scheme = Editor.syntaxHighlightingSchemeFor(ext: file.url.pathExtension)
                
                if scheme == nil {
                    actions.append(.showSourceAction {
                        _ in self.openSourceCode(file: file)
                        })
                } else {
                    actions.append(.showContentAction {
                        _ in self.openInBrowser(file: file, config: nil, force: true)
                        })
                }
            }
            
            actions.append(.shareAction {
                _ in self.shareFile(at: indexPath)
                })
            
            actions.append(.moveAction {
                _ in self.selectFileToRelocate(at: indexPath)
                })
            
            return actions
        }
        
        return []
    }
    
    override internal func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        
        var actions: [FileDetailViewController.Action]
        let file = files[indexPath.row]
        
        if fileListManager.isRelocatingFiles {
            actions = [.delete, .rename, .clone]
        } else {
            actions = [.delete, .move, .rename, .clone, .share]
            
            if file is FSNode.File {
                let ext = getFileExtensionFromString(fileName: file.name)
                switch ext {
                case "css":
                    actions.append(.archive)
                    break;
                case "js":
                    actions.append(.archive)
                    break;
                case "zip":
                    actions.append(.unarchive)
                    break;
                default:
                    actions.append(.archive)
                    break
                }
            } else {
                actions.append(.archive)
            }
        }
        
        let detailController = FileDetailViewController.getNew(observatingFile: files[indexPath.row], actions: actions)
        let navigationController = ThemeColoredNavigationController(rootViewController: detailController)
        
        detailController.delegate = self
        detailController.dataSource = self
        
        navigationController.modalPresentationStyle = .formSheet
        
        view.window?.rootViewController!.present(navigationController, animated: true, completion: nil)
    }
    
    override internal func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0.01 : 10
    }
    
    override internal func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override internal func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            let view = UIView(frame: headerView.bounds)
            view.backgroundColor = userPreferences.currentTheme.background
            headerView.backgroundView = view
        }
    }
    
    // MARK: NewFileDialog delegate
    
    func newFileDialog(dialog: NewFileDialog, hasPicked image: UIImage) {
        if let data = image.pngData() {
            
            let url = self.url!
            
            let name = FileBrowser.getAvailableFileName(fileName: "image.png", path: url.path)
            try? data.write(to: url.appendingPathComponent(name))
            
            FileBrowser.fileListUpdatedAt(url: url)
        }
    }
    
    // MARK: FileCreationDialog delegate
    
    internal func fileForName(name: String) -> FSNode? {
        for file in files {
            if file.name == name {
                return file
            }
        }
        return nil
    }
    
    func fileDetail(pathTo file: FSNode) -> String {
        return url.path
    }
    
    internal func fileDetail(controller: FileDetailViewController, shouldMove file: FSNode) {
        
        if let index = files.firstIndex(of: file) {
            selectFileToRelocate(at: IndexPath(row: index, section: 0))
        }
    }
    
    internal func fileDetail(creationDateOf file: FSNode) -> Date? {
        return getFileAttrubutes(fileName: file.url.path).fileCreationDate()
    }
    
    internal func fileDetail(modificationDateOf file: FSNode) -> Date? {
        return getFileAttrubutes(fileName: file.url.path).fileModificationDate()
    }
    
    internal func fileDetail(sizeOf file: FSNode, completion: @escaping (Int64) -> ()) -> CancellableRequest! {
        
        if let file = file as? FSNode.File {
            completion(file.size)
            return nil
        }
        
        let task = DispatchWorkItem {
            let size = getFolderSize(at: file.url.path)
            DispatchQueue.main.async {
                completion(Int64(size))
            }
        }
        
        DispatchQueue(label: "easyhtml.foldersizecalculationtask").async(execute: task)
        
        return CancellableRequest {
            _ in
            task.cancel()
        }
    }
    
    internal func fileDetail(controller: FileDetailViewController, objectsToShare file: FSNode, callback: ((Bool, URL) -> ())) {
        callback(false, file.url)
    }
    
    override func receiveFile(file: String, from source: FileSourceType, storedAt atURL: URL, callback: @escaping FilesRelocationCompletion, progress: @escaping (Float) -> ()) {
        fatalError("Container is read-only")
    }
    
    override func prepareToRelocation(file: FSNode, to destination: FileSourceType, completion: @escaping (URL?, Error?) -> (), progress: @escaping (Float) -> ()) {
        
        completion(file.url, nil)
        
        FileBrowser.fileListUpdatedAt(url: self.url)
        
        needsUpdate = true
    }
    
    override func canReceiveFile(file: FSNode, from source: FileSourceType) -> FilesRelocationManager.FileReceiveability {
        
        return .no(reason: .unsupportedController)
    }
    
    deinit {
        TemproraryFileMetadataManager.clearJunkMetadataForFiles(files: self.files)
    }
}

