//
//  DropboxFileListTableView.swift
//  EasyHTML
//
//  Created by Артем on 18.04.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit
import SwiftyDropbox
import Zip

internal class DropboxFileListTableView: FileListController, FileListDelegate, FileListDataSource, UIPopoverPresentationControllerDelegate, FileDetailDelegate, FileDetailDataSource, FileCreationDialogDelegate, NewFileDialogDelegate, LibraryPickerDelegate {

    private var isRoot = true
    
    private var folderLoadingRequest: RpcRequest<Files.ListFolderResultSerializer, Files.ListFolderErrorSerializer>! = nil
    
    static var isDropboxInitialized = false
    static var isDropboxSetupFinished = false
    static var applicationKey = "dropbox-application-key"
    
    static weak var rootController: DropboxFileListTableView!
    
    private var files: [FSNode] = []
    internal var filesList: [FSNode] {
        get {
            return files
        }
    }
    override var sourceType: FileSourceType {
        return .dropbox
    }
    
    internal override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        waitingForNextLongpoolRequest = false
        folderLoadingRequest?.cancel()
        folderLoadingRequest = nil
        stopLongpoolRequest()
    }
    
    internal override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !cursor.isEmpty {
            startLongpoolRequest()
        }
    }
    
    private var downloadingMore = false
    private var hasMore = false
    private var cursor: String = ""
    
    internal var longpoolRequest: RpcRequest<Files.ListFolderLongpollResultSerializer, Files.ListFolderLongpollErrorSerializer>? = nil
    
    private func downloadMore() {
        
        self.stopLongpoolRequest()
        
        if(downloadingMore) {
            return
        }
        downloadingMore = true
    
        shouldShowActivityIndicatorAtBottom = true
        
        let client = DropboxClientsManager.authorizedClient!
        client.files.listFolderContinue(cursor: self.cursor).response { (response, error) in
            if error == nil, let response = response {
                self.cursor = response.cursor
                self.hasMore = response.hasMore
                self.downloadingMore = false
                
                let oldFilesCount = self.files.count
                
                for file in response.entries {
                    self.insertResponseFile(file: file)
                }
                self.hideEmptyFolderWarning()
                var indexPaths = [IndexPath]()
                
                for index in oldFilesCount ..< self.files.count {
                    indexPaths.append(IndexPath(row: index, section: 0))
                }
                
                self.shouldShowActivityIndicatorAtBottom = false
                
                self.startLongpoolRequest()
                
                self.tableView.insertRows(at: indexPaths, with: .none)
                
            } else {
                if let error = error {
                    switch error {
                    case .rateLimitError(let rateLimitError, _, _, _):
                        let seconds = rateLimitError.retryAfter
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(seconds))) {
                            self.downloadMore()
                        }
                        return
                    default: break
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    [weak self] in
                    self?.downloadMore()
                }
            }
        }
    }
    
    internal var waitingForNextLongpoolRequest = false
    
    internal func startLongpoolRequest() {
        
        func startNextRequest(delay: TimeInterval) {
            self.waitingForNextLongpoolRequest = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                if self.waitingForNextLongpoolRequest && self.longpoolRequest == nil {
                    self.waitingForNextLongpoolRequest = false
                    self.startLongpoolRequest()
                }
            })
        }
        
        let client = DropboxClientsManager.authorizedClient!
        
        longpoolRequest = client.files.listFolderLongpoll(cursor: cursor)
        longpoolRequest?.response(completionHandler: { (result, error) in
            
            if let result = result {
                let delay: TimeInterval = Double(result.backoff ?? 1)
                
                self.longpoolRequest = nil
                if result.changes {
                    func tryReloadDirectory() {
                        self.reloadFolderLongpool(completion: {
                            success in
                            if success {
                                startNextRequest(delay: delay)
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                                    tryReloadDirectory()
                                })
                            }
                        })
                    }
                    
                    tryReloadDirectory()
                } else {
                    startNextRequest(delay: delay)
                }
            }
        })
    }
    
    internal func reloadFolderLongpool(completion: ((Bool) -> ())! = nil) {
        
        let client = DropboxClientsManager.authorizedClient!
        
        
        client.files.listFolderContinue(cursor: cursor).response(completionHandler: { (result, error) in
            self.folderLoadingRequest = nil
            
            if let result = result {
                
                result.entries.forEach({ (metadata) in
                    
                    if let metadata = metadata as? Files.DeletedMetadata {
                        
                        var index = -1
                        var i = 0
                        
                        /*
                            Здесь не используется index(of: FSObject), так как сравнение Dropbox-файлов идет по
                            их ID, что будет мешать анимировать переименовывание файла, так как оно
                            реализовано путём его "перемещения" внутри одной и той же папки, но с разными
                            именами. при перемещении файла longpool-запрос отправляет сначала сигнал о удалении
                            файла из директории-источника, при этом ID файла не меняется.
                        */
                        
                        for file in self.files {
                            if file.name == metadata.name {
                                index = i
                                break
                            }
                            i += 1
                        }
                        
                        if(index == -1) {
                            return
                        }
                        
                        let deletedFile = self.files[index]
                        self.files.remove(at: index)
                        
                        TemproraryFileMetadataManager.clearMetadata(forFile: deletedFile)
                        
                        let indexPath = IndexPath(row: index, section: 0)
                        
                        self.tableView.deleteRows(at: [indexPath], with: .left)
                        
                    } else {
                        let path = metadata.pathDisplay!.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                        let url = URL(string: path)!
                        if let metadata = metadata as? Files.FileMetadata {
                            
                            /*
                                Мы не создаем новую инстанцию File, поскольку заново маллокать память,
                                инициализировать объект, столько действий лишних, фу.
                                Так просто проще.
                             */
                            
                            if let index = self.index(of: metadata.id), let file = self.files[index] as? DropboxFile {
                                
                                file.url = url
                                file.metadata = metadata
                                
                                self.files.remove(at: index)
                                self.files.append(file)
                                self.tableView.moveRow(
                                    at: IndexPath(row: index, section: 0),
                                    to: IndexPath(row: self.files.count - 1, section: 0)
                                )
                            } else {
                                let file = DropboxFile(url: url, metadata: metadata)
                                self.files.append(file)
                                self.tableView.insertRows(at: [IndexPath(row: self.files.count - 1, section: 0)], with: .fade)
                            }
                            
                        } else if let metadata = metadata as? Files.FolderMetadata {
                            
                            var newIndex = 0
                            
                            for item in self.files {
                                if(item is DropboxFolder) {
                                    newIndex += 1
                                    continue
                                }
                                break
                            }
                            
                            /*
                                Мы не создаем новую инстанцию Folder, поскольку хотим сохранить
                                информацию о количестве файлов внутри. Да и заново маллокать
                                память, инициализировать объект, столько действий лишних, фу.
                                Так просто проще.
                             */
                            
                            if let index = self.index(of: metadata.id), let folder = self.files[index] as? DropboxFolder {
                                
                                folder.url = url
                                folder.metadata = metadata
                                
                                self.files.remove(at: index)
                                
                                if index < newIndex {
                                    newIndex -= 1
                                }
                                
                                self.files.insert(folder, at: newIndex)
                                self.tableView.moveRow(
                                    at: IndexPath(row: index, section: 0),
                                    to: IndexPath(row: newIndex, section: 0)
                                )
                            } else {
                                let folder = DropboxFolder(url: url, metadata: metadata)
                                self.files.insert(folder, at: newIndex)
                                self.hideEmptyFolderWarning()
                                self.tableView.insertRows(at: [IndexPath(row: newIndex, section: 0)], with: .fade)
                            }
                        }
                    }
                })
                
                self.checkFolderIsEmpty()
                
                self.updateCellColors()
                self.cursor = result.cursor
                
                completion(true)
            } else {
                completion(false)
            }
        })
    }
    
    internal func index(of id: String) -> Int?{
        var i = 0
        for file in files {
            if let file = file as? DropboxFile {
                if id == file.metadata.id {
                    return i
                }
            } else if let folder = file as? DropboxFolder {
                if id == folder.metadata.id {
                    return i
                }
            }
            
            i += 1
        }
        
        return nil
    }
    
    internal func stopLongpoolRequest() {
        
        self.longpoolRequest?.cancel()
        self.waitingForNextLongpoolRequest = false
        self.longpoolRequest = nil
    }
    
    internal override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        super.scrollViewDidScroll(scrollView)
        
        if(downloadingMore || !hasMore || cursor.isEmpty || isLoading) {
            return
        }
        
        let offset = scrollView.contentOffset.y
        
        let maxOffset = scrollView.contentSize.height - scrollView.frame.height
        
        if offset > maxOffset - 200 {
            downloadMore()
        }
    }
    
    internal override func updateNavigationItemButtons() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createNewFile))
        navigationItem.leftBarButtonItem = nil
    }
    
    internal override func viewDidLoad() {
        
        super.viewDidLoad()
        
        makeReloadable()
        
        fileListDelegate = self
        fileListDataSource = self
        
        if(isRoot) {
            DropboxFileListTableView.rootController = self
            self.title = "Dropbox"
            self.url = URL(string: "/")
        }
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: self.title, style: .plain, target: nil, action: nil)
        
        if(!DropboxFileListTableView.isDropboxSetupFinished) {
            DropboxClientsManager.setupWithAppKey(DropboxFileListTableView.applicationKey)
            DropboxFileListTableView.isDropboxSetupFinished = true
        }
        
        self.isLoading = true
        
        if !DropboxFileListTableView.isDropboxInitialized &&
            DropboxClientsManager.authorizedClient == nil {
        
            DropboxClientsManager.authorizeFromController(
                UIApplication.shared,
                controller: UIApplication.shared.keyWindow!.rootViewController,
                openURL: { (url: URL) -> Void in
                    UIApplication.shared.openURL(url)
                }
            )
        } else {
            DropboxFileListTableView.isDropboxInitialized = true
            reloadDirectory()
        }
        
        isLoading = true
        
        fileRefreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        NotificationCenter.default.addObserver(self, selector: #selector(fileMetadataDidChange(_:)), name: .TCFileMetadataChanged, object: nil)
    }
    
    @objc func refresh() {
        reloadDirectory()
    }
    
    @objc func createNewFile() {
        
        let config: NewFileDialog.Config
        
        if fileListManager.isRelocatingFiles {
            config = NewFileDialog.Config(
                canCreateFiles:     false,
                canCreateFolders:   true,
                canImportPhotos:    false,
                canImportLibraries: false
            )
        } else {
            config = NewFileDialog.Config(
                canCreateFiles:     true,
                canCreateFolders:   true,
                canImportPhotos:    true,
                canImportLibraries: true
            )
        }
        
        let alert = NewFileDialog(config: config)
        
        alert.window = view.window
        alert.delegate = self
        alert.fileCreationDelegate = self
        alert.libraryPickerDelegate = self
        
        view.window!.addSubview(alert.alert.view)
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
    
    internal func insertResponseFile(file: Files.Metadata, at index: Int = -1) {
        let path = file.pathDisplay!.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
        let url = URL(string: path)!
        
        if let fileMetadata = file as? Files.FileMetadata {
            
            let file = DropboxFile(url: url, metadata: fileMetadata)
            if(index == -1) {
                self.files.append(file)
            } else {
                self.files.insert(file, at: index)
            }
            
        } else if let folderMetadata = file as? Files.FolderMetadata {
            
            let index = self.files.count
            
            let folder = DropboxFolder(url: url, metadata: folderMetadata)
            folder.getCountOfFilesInsideAsync(completion: { (success, result) in
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            })
            
            if(index == -1) {
                self.files.append(folder)
            } else {
                self.files.insert(folder, at: index)
            }
        }
    }
    
    internal func reloadDirectory() {
        self.stopLongpoolRequest()
        
        let client = DropboxClientsManager.authorizedClient!
        
        // Проверка адреса корневой директории.
        // Dropbox API возвращает ошибку при попытке
        // загрузить содержимое корневой папки
        // используя адрес "/". Не совсем понятно,
        // какова была цель этого ограничения, но
        // его приходится соблюдать, куда деваться.
        
        var path = url!.path
        if path == "/" {
            path = ""
        }
        
        folderLoadingRequest = client.files.listFolder(path: path, recursive: false, includeMediaInfo: false, includeDeleted: false, includeHasExplicitSharedMembers: false, includeMountedFolders: true, limit: 40, sharedLink: nil, includePropertyGroups: nil).response(completionHandler: { (result, error) in
            
            self.folderLoadingRequest = nil
            self.removeErrorLabel()
            self.isLoading = false
            
            if error == nil, let result = result {
                self.hasMore = result.hasMore
                self.cursor = result.cursor
                
                self.files = []
                result.entries.forEach({ (file) in
                    self.insertResponseFile(file: file)
                })
                
                self.checkFolderIsEmpty()
                self.startLongpoolRequest()
                
                if self.fileRefreshControl?.isRefreshing == true {
                    self.tableView.reloadData()
                    self.fileRefreshControl.endRefreshing()
                } else {
                    UIView.transition(with: self.tableView, duration: 0.35, options: .transitionCrossDissolve, animations: {
                        self.tableView.reloadData()
                    })
                }
            } else {
                if error != nil {
                    if case let .clientError(error) = error! {
                        if error != nil, (error! as NSError).code == -999 {
                            return
                        }
                    } else if case .authError = error! {
                        DropboxClientsManager.unlinkClients()
                        
                        DropboxClientsManager.authorizeFromController(
                            UIApplication.shared,
                            controller: UIApplication.shared.keyWindow!.rootViewController,
                            openURL: { (url: URL) -> Void in
                                UIApplication.shared.openURL(url)
                        }
                        )
                        
                        return
                    }
                }
                
                self.fileRefreshControl.endRefreshing()
                
                self.files = []
                self.showErrorLabel(text: error?.generalized.localizedDescription);
                self.isLoading = false
                self.tableView.reloadData()
            }
        })
    }
    
    private func checkFolderIsEmpty() {
        if files.isEmpty {
            if(!emptyFolderWarningShown) {
                showEmptyFolderWarning()
            }
        } else {
            hideEmptyFolderWarning()
        }
    }
    
    internal func fileList(fileForRowAt index: Int) -> FSNode {
        return files[index]
    }
    
    internal func countOfFiles() -> Int {
        return files.count
    }
    
    internal func fileList(selectedFileAt index: Int) {
        let file = files[index]
        openFile(file: file)
    }
    
    func openFile(file: FSNode, inNewTab: Bool = false) {
        if let folder = file as? FSNode.Folder {
            navigateTo(directory: folder)
        } else if !fileListManager.isRelocatingFiles, let file = file as? DropboxFile {
            let e = getFileExtensionFromString(fileName: file.name)
            
            if e == "zip" || e == "rar" {
                FileListController.presentRemoteUnarchiveWarning(on: view.window!)
                return
            }
            
            var config: EditorConfiguration = [.ioManager : DropboxIOManager()]
            
            if inNewTab {
                config[.openInNewTab] = true
            }
            
            if(Editor.imageExtensions.contains(e)) {
                self.openAsImage(file: file, config: config)
            } else if(Editor.syntaxHighlightingSchemeFor(ext: e) != nil) {
                self.openSourceCode(file: file, config: config)
            } else {
                self.openInBrowser(file: file, config: config)
            }
        }
    }
    
    internal func navigateTo(directory: FSNode.Folder) {
        
        /*
         Поскольку при копировании файлов контоллеры не удаляются из памяти,
         мы можем оптимизировать память.
         */
        
        if let controller = fileListManager.getCachedController(for: directory.url, with: sourceType) {
            navigationController?.pushViewController(controller, animated: true)
            return
        }
        
        let controller = DropboxFileListTableView()
        
        controller.fileListManager = fileListManager
        controller.isRoot = false
        controller.url = self.url?.appendingPathComponent(directory.name)
        controller.title = directory.name
        
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    func openSourceCode(file: FSNode.File, config: EditorConfiguration) {
        super.openSourceCode(file: file, config: config)
    }
    
    func openAsImage(file: FSNode.File, config: EditorConfiguration) {
        super.openAsImage(file: file, config: config)
    }
    
    func openInBrowser(file: FSNode.File, config: EditorConfiguration) {
        super.openInBrowser(file: file, config: config)
    }
    
    override internal func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        
        let detailController = FileDetailViewController.getNew(observatingFile: files[indexPath.row], actions: [.delete, .rename, .clone, .move])
        
        detailController.delegate = self
        detailController.dataSource = self
        
        let navigationController = ThemeColoredNavigationController(rootViewController: detailController)
        
        navigationController.modalPresentationStyle = .formSheet
        
        view.window!.rootViewController!.present(navigationController, animated: true, completion: nil)
    }
    
    internal func fileList(deleted file: FSNode) {
        
        let alert = NetworkOperationDialog()
        alert.alert.header.text = localize("deleting")
        
        let client = DropboxClientsManager.authorizedClient!
        
        func startRequest() {
            alert.operationStarted()
            
            let request = client.files.deleteV2(path: file.url.path).response(completionHandler: { (metadata, error) in
                if error == nil {
                    alert.operationCompleted()
                    if let index = self.files.firstIndex(of: file) {
                        self.files.remove(at: index)
                        self.checkFolderIsEmpty()
                        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
                    }
                    
                    if file is FSNode.File {
                        userPreferences.statistics.filesDeleted += 1
                    } else {
                        userPreferences.statistics.foldersDeleted += 1
                    }
                    
                    Editor.fileDeleted(file: file)
                } else {
                    alert.operationFailed(with: error?.generalized, retryHandler: {
                        startRequest()
                    })
                }
            })
            
            alert.cancelHandler = {
                request.cancel()
            }
        }
        
        alert.present(on: view.window!)
        
        startRequest()
    }
    
    func shortcutActionsForFile(file: FSNode, at index: Int) -> [ContextMenuAction] {
        let indexPath = IndexPath(row: index, section: 0)
        
        if file is FSNode.Folder {
            return [
                .moveAction {
                    _ in self.selectFileToRelocate(at: indexPath)
                }
            ]
        } else if let file = file as? FSNode.File {
            
            var actions: [ContextMenuAction] = [
                .openInNewTabAction {
                    _ in self.openFile(file: file, inNewTab: true)
                }
            ]
            
            let scheme = Editor.syntaxHighlightingSchemeFor(ext: file.url.pathExtension)
            
            if scheme == nil {
                actions.append(.showSourceAction {
                    _ in self.openSourceCode(file: file, config: [.ioManager : DropboxIOManager()])
                    })
            } else {
                actions.append(.showContentAction {
                    _ in self.openInBrowser(file: file, config: [.ioManager : DropboxIOManager()], force: true)
                    })
            }
            
            actions.append(.moveAction {
                _ in self.selectFileToRelocate(at: indexPath)
                })
            
            return actions
        }
        return []
    }
    
    
    // MARK: FileDetailViewController Delegate
    
    internal func fileDetail(controller: FileDetailViewController, shouldDelete file: FSNode) {
        self.fileList(deleted: file)
    }
    
    internal func fileDetail(controller: FileDetailViewController, shouldRename file: FSNode, to newName: String) {
        let client = DropboxClientsManager.authorizedClient!
        
        let alert = NetworkOperationDialog()
        alert.alert.header.text = localize("renaming", .files)
        
        func startRequest() {
            alert.operationStarted()
            
            let availableName = getAvailableFileName(fileName: newName)
            
            let newURL = file.url.deletingLastPathComponent().appendingPathComponent(availableName)
            
            let request = client.files.moveV2(fromPath: file.url.path, toPath: newURL.path).response { result, error in
                if let error = error {
                    alert.operationFailed(with: error.generalized, retryHandler: {
                        startRequest()
                    })
                } else {
                    alert.operationCompleted()
                    
                    if let index = self.files.firstIndex(of: file) {
                        self.files[index].name = availableName
                        if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? FileListCell {
                            cell.title.setTextWithFadeAnimation(text: availableName)
                        }
                    }
                    
                    Editor.fileMoved(file: file, to: newURL)
                }
            }
            
            alert.cancelHandler = {
                request.cancel()
            }
        }
        
        alert.present(on: view.window!)
        
        startRequest()
    }
    
    internal func cloneFile(file: FSNode) {
        let client = DropboxClientsManager.authorizedClient!
        
        let alert = NetworkOperationDialog()
        alert.alert.header.text = localize("cloning", .files)
        
        func startRequest() {
            alert.operationStarted()
            
            var availableName = FileBrowser.clonedFileName(fileName: file.name)
            availableName = getAvailableFileName(fileName: availableName)
            
            let newURL = file.url.deletingLastPathComponent().appendingPathComponent(availableName)
            
            let request = client.files.copyV2(fromPath: file.url.path, toPath: newURL.path).response { _, error in
                if let error = error {
                    alert.operationFailed(with: error.generalized, retryHandler: {
                        startRequest()
                    })
                } else {
                    alert.operationCompleted()
                }
            }
            
            alert.cancelHandler = {
                request.cancel()
            }
        }
        
        alert.present(on: view.window!)
        
        startRequest()
    }
    
    internal func fileDetail(controller: FileDetailViewController, shouldClone file: FSNode) {
        cloneFile(file: file)
    }
    
    func fileDetail(sourceNameOf file: FSNode) -> String {
        return "Dropbox"
    }
    
    internal func fileForName(name: String) -> FSNode? {
        for file in files {
            if file.name == name {
                return file
            }
        }
        return nil
    }
    
    internal func getAvailableFileName(fileName: String) -> String {
        let components = getFileNameAndExtensionFromString(fileName: fileName)
        
        var ext = components[1]
        
        if !ext.isEmpty {
           ext = "." + ext
        }
        
        var name: String
        var index = 0
        
        repeat {
            if(index == 0) {
                name = fileName
            } else {
                name = "\(components[0]) \(index)\(ext)"
            }
            
            index += 1
            
        } while fileForName(name: name) != nil
        
        return name
    }
    
    // MARK: FileDetailViewController DataSource
    
    /*
     internal func fileDetail(creationDateOf file: FSObject) -> Date? {
        // Дату создания файла невозможно получить в текущей версии Dropbox API
        // Принудительный возврат nil в этом методе эквивалентен отказу от его
        // реализации в классах, реализующих протокол FileDetailDataSource.
        // Для экономии оперативной памяти и повышения производительности
        // данный метод оставлен не реализованным.
     
        // return nil // <-- Раскомментировать в случае ядерной войны
    }
     */
    
    internal func fileDetail(modificationDateOf file: FSNode) -> Date? {
        if let file = file as? DropboxFile {
            return file.metadata.clientModified
        }
        
        return nil
    }
    
    func fileDetail(sizeOf file: FSNode, completion: @escaping (Int64) -> ()) -> CancellableRequest! {
        if let file = file as? FSNode.File {
            completion(file.size)
            return nil
        }
        completion(-1)
        return nil
    }
    
    internal func fileDetail(sizeOf file: FSNode) -> Int64 {
        if let file = file as? FSNode.File {
            return file.size
        }
        return -1
    }
    
    // MARK: NewFileDialog delegate
    
    func newFileDialog(dialog: NewFileDialog, hasPicked image: UIImage) {
        guard let data = image.pngData() else {return}
            
        let alert = NetworkOperationDialog()
        alert.alert.header.text = localize("uploadingphoto", .files)
        
        let client = DropboxClientsManager.authorizedClient!
        
        func startRequest() {
            alert.operationStarted()
            
            let path = self.url!.appendingPathComponent(getAvailableFileName(fileName: "image.png")).path
            
            let request = client.files.upload(path: path, input: data).response(completionHandler: { (metadata, error) in
                if error == nil {
                    alert.operationCompleted()
                } else {
                    alert.operationFailed(with: error?.generalized, retryHandler: {
                        startRequest()
                    })
                }
            }).progress { (progress) in
                alert.setProgress(Float(progress.fractionCompleted))
            }
            
            alert.cancelHandler = {
                request.cancel()
            }
        }
        
        alert.present(on: view.window!)
        
        startRequest()
    }
    
    // MARK: FileCreationDialog delegate
    
    internal func fileCreationDialog(controller: FileCreationDialog, createFile named: String, completion: @escaping (FileCreationResult) -> ()) {
        if fileForName(name: named) != nil {
            completion(.filenameUsed)
        }
        
        let ext = getFileExtensionFromString(fileName: named)
        let data: Data?
        
        if ext == "" {
            data = nil
        } else {
            data = bundleFileData(name: ext, ext: "exmp")
        }
        
        let path = url!.appendingPathComponent(named).path
        
        let client = DropboxClientsManager.authorizedClient!
        client.files.upload(path: path, input: data ?? "".data(using: .utf8)!).response { (metadata, error) in
            if let error = error {
                if case .routeError(let boxed, _, _, _) = error, case .path(let uploadError) = boxed.unboxed {
                    if case .conflict(_) = uploadError.reason {
                        completion(.filenameUsed)
                        return
                    } else if case .disallowedName = uploadError.reason {
                        completion(.wrongName)
                        return
                    }
                }
                
                completion(.other)
            } else {
                userPreferences.statistics.filesCreated += 1
                completion(.success)
            }
        }
    }
    
    internal func fileCreationDialog(controller: FileCreationDialog, createFolder named: String, completion: @escaping (FileCreationResult) -> ()) {
        if fileForName(name: named) != nil {
            completion(.filenameUsed)
        }
        
        let path = url!.appendingPathComponent(named).path
        
        let client = DropboxClientsManager.authorizedClient!
        
        client.files.createFolderV2(path: path).response { (result, error) in
            if let error = error {
                if case .routeError(let boxed, _, _, _) = error, case .path(let writeError) = boxed.unboxed {
                    if case .conflict(_) = writeError {
                        completion(.filenameUsed)
                        return
                    } else if case .disallowedName = writeError {
                        completion(.wrongName)
                        return
                    }
                }
                
                completion(.other)
            } else {
                completion(.success)
                userPreferences.statistics.foldersCreated += 1
            }
        }
    }
    
    // MARK: LibraryPickerDelegate
    
    private func uploadLibrary(library: Library) {
        let localURL = library.getLocalFileURL()
        guard let data = try? Data(contentsOf: localURL) else {
            print("[EasyHTML] [DropboxFileListTableView] -libraryPicker(didSelect library:Library) Failed to retreive library binary data! Cancelling.")
            return
        }
        
        let alert = NetworkOperationDialog()
        alert.alert.header.text = localize("uploadinglibrary", .files)
        
        let client = DropboxClientsManager.authorizedClient!
        
        func startRequest() {
            alert.operationStarted()
            
            let path = self.url.appendingPathComponent(getAvailableFileName(fileName: library.name + library.ext)).path
            
            let request = client.files.upload(path: path, input: data).response(completionHandler: { (metadata, error) in
                if error == nil {
                    alert.operationCompleted()
                } else {
                    alert.operationFailed(with: error?.generalized, retryHandler: {
                        startRequest()
                    })
                }
            }).progress { (progress) in
                alert.setProgress(Float(progress.fractionCompleted))
            }
            
            alert.cancelHandler = {
                request.cancel()
            }
        }
        
        alert.present(on: view.window!)
        
        startRequest()
    }
    
    private func showLibraryZIPWarning(library: Library) {
        
        let alert = TCAlertController.getNew()
        alert.contentViewHeight = 100
        alert.constructView()
        alert.applyDefaultTheme()
        alert.makeCloseableByTapOutside()
        
        let textView = alert.addTextView()
        
        textView.text = localize("dropboxziplibrarywarndesc", .files).replacingOccurrences(of: "#", with: library.name)
        alert.headerText = localize("dropboxziplibrarywarn", .files)
        
        alert.addAction(action: TCAlertAction(text: localize("yes"), action: { _, _ in
            self.uploadLibrary(library: library)
        }, shouldCloseAlert: true))
        
        alert.addAction(action: TCAlertAction(text: localize("no"), shouldCloseAlert: true))
        
        view.window!.rootViewController?.present(alert, animated: true, completion: nil)
    }
    
    func libraryPicker(didSelect library: Library) {
        
        if library.ext == ".zip" {
            showLibraryZIPWarning(library: library)
        } else {
            uploadLibrary(library: library)
        }
        
    }
    
    override func prepareToRelocation(file: FSNode, to destination: FileSourceType, completion: @escaping (URL?, Error?) -> (), progress: @escaping (Float) -> ()) {
        
        if case .dropbox = destination {
            
            completion(file.url, nil)
            
        } else {
            
            // Загружаем файл в временную директорию
            
            guard let client = DropboxClientsManager.authorizedClient else { return }
            var tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            
            tempURL.appendPathComponent(UUID().uuidString)
            
            if let file = file as? DropboxFile {
                client.files.download(path: file.url.path, rev: nil, destination: { (_, _) -> URL in
                    return tempURL
                }).response(completionHandler: { (info, error) in
                    if error != nil {
                        completion(nil, DropboxError(error: error?.generalized))
                    } else {
                        completion(tempURL, nil)
                    }
                }).progress {
                    progress(Float($0.fractionCompleted))
                }
            } else if let file = file as? DropboxFolder {
                
                let zipURL = tempURL.appendingPathExtension("zip")
                
                client.files.downloadZip(path: file.url.path, destination: { (_, _) -> URL in
                    return zipURL
                }).response(completionHandler: { (result, error) in
                    if error != nil {
                        completion(nil, DropboxError(error: error!.generalized))
                    } else {
                        DispatchQueue.global().async {
                            do {
                                var finished = false
                                try Zip.unzipFile(zipURL, destination: tempURL, overwrite: false, password: nil, progress: {
                                    progress in
                                    
                                    if progress == 1 && !finished {
                                        finished = true
                                        
                                        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
                                        let tempDir1 = tempURL.appendingPathComponent(file.name)
                                        let tempDir2 = temp.appendingPathComponent(UUID().uuidString)
                                        
                                        // Немного магии...
                                        
                                        // Вжух #1
                                        try? FileManager.default.removeItem(at: zipURL)
                                        
                                        // Вжух #2
                                        try? FileManager.default.moveItem(atPath: tempDir1.path, toPath: tempDir2.path)
                                        
                                        // Вжух #3
                                        try? FileManager.default.removeItem(at: tempURL)
                                        
                                        // Пентагон взломан
                                        
                                        DispatchQueue.main.async {
                                            completion(tempDir2, nil)
                                        }
                                    }
                                })
                            } catch {
                                DispatchQueue.main.async {
                                    completion(nil, error)
                                }
                            }
                        }
                    }
                }).progress {
                    progress(Float($0.fractionCompleted))
                }
            }
        }
    }
    
    private func uploadFile(at localURL: URL, to destinationURL: URL, callback: @escaping (Error?) -> (), progress: ((Float) -> ())?) {
        
        guard let client = DropboxClientsManager.authorizedClient else { callback(nil); return }
        
        var stream: DropboxInputStream!
        
        var started = false
        
        let maxPackageSize: UInt64 = 157286400 // 150 MB
        
        func completionHandler(sessionId: String!, error: CallError<()>?) {
            
            let uploaded = stream.bytesReaden
            
            let cursor = sessionId == nil ? nil : Files.UploadSessionCursor(sessionId: sessionId, offset: uploaded)
            
            if let error = error {
                if case let .rateLimitError(error, _, _, _) = error {
                    let delay = Int(error.retryAfter)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: {
                        [started] in
                        if started && cursor != nil {
                            continueUploading(cursor: cursor!)
                        } else {
                            upload()
                        }
                    })
                } else {
                    callback(DropboxError(error: error.generalized))
                }
                return
            }
            
            started = true
            
            stream.maxStreamDataSize += maxPackageSize
            
            if stream.hasBytesAvailable {
                continueUploading(cursor: cursor!)
            } else {
                finishUploading(cursor: cursor!)
            }
        }
        
        func finishUploading(cursor: Files.UploadSessionCursor) {
            
            let commitInfo = Files.CommitInfo(path: destinationURL.path)
            
            func completionHandler(metadata: Files.Metadata!, error: CallError<(Files.UploadSessionFinishError)>!) {
                if error != nil {
                    if case let .rateLimitError(error, _, _, _) = error! {
                        let delay = Int(error.retryAfter)
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
                            finish()
                        }
                    } else {
                        callback(DropboxError(error: error.generalized))
                    }
                    return
                }
                
                callback(nil)
            }
            
            func finish() {
                client.files.uploadSessionFinish(cursor: cursor, commit: commitInfo, input: "".data(using: .ascii)!).response(completionHandler: completionHandler)
                
            }
            
            finish()
        }
        
        func continueUploading(cursor: Files.UploadSessionCursor) {
            client.files.uploadSessionAppendV2(cursor: cursor, input: stream)
        }
        
        func upload() {
            client.files.uploadSessionStart(input: stream).response(completionHandler: {
                result, error in
                completionHandler(sessionId: result?.sessionId, error: error)
            }).progress { _ in
                progress?(stream.fractionCompleted)
            }
        }
        
        func createStream() {
            stream = DropboxInputStream(url: localURL)
            
            guard stream != nil else {
                
                callback(NSError(
                    domain: "easyhtml",
                    code: -12,
                    userInfo: [NSLocalizedDescriptionKey : "Failed to create input stream"]
                ))
                
                return
            }
            
            if(stream.fileLength < Float(maxPackageSize)) {
                func request() {
                    
                    func result(result: Files.FileMetadata?, error: CallError<Files.UploadError>?){
                        if let error = error {
                            if case let .rateLimitError(error, _, _, _) = error {
                                let delay = Int(error.retryAfter)
                                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
                                    request()
                                }
                            } else {
                                callback(DropboxError(error: error.generalized))
                            }
                        } else {
                            callback(nil)
                        }
                    }
                    
                    if(stream.fileLength == 0) {
                        client.files.upload(path: destinationURL.path, input: "".data(using: .ascii)!)
                            .response(completionHandler: result)
                    } else {
                        client.files.upload(path: destinationURL.path, input: stream)
                            .response(completionHandler: result).progress {
                                progress?(Float($0.completedUnitCount) / stream.fileLength)
                        }
                        
                    }
                }
                
                request()
            } else {
                upload()
            }
        }
        
        createStream()
    }
    
    private func uploadFolder(at localURL: URL, to destinationURL: URL, callback: @escaping (Error?) -> (), progress: ((Float) -> ())?) {
        
        guard let client = DropboxClientsManager.authorizedClient else { callback(nil); return }
        
        /*
             Итак, нас ждет долгое приключение под названием "Загрузка папки на сервер Dropbox"
             Итерируя по каждому элементу в локальной папке, по одному файлу мы создаем
             копию папки на сервере. Весело, правда?
         */
        
        var subpaths: IndexingIterator<[String]>
        let count: Float
        var ignore: String?
        
        do {
            var paths = try FileManager.default.subpathsOfDirectory(atPath: localURL.path)
            count = Float(paths.count) + 1
            paths.insert("", at: 0)
            subpaths = paths.makeIterator()
        } catch {
            callback(error)
            return
        }
        
        var completed: Float = 0
        
        func nextRequest() -> Bool {
            
            guard let relativePath = subpaths.next() else {
                callback(nil)
                return false
            }
            
            if(ignore != nil) {
                if(relativePath.hasPrefix(ignore!)) {
                    return true
                } else {
                    ignore = nil
                }
            }
           
            
            let absoluteURL = localURL.appendingPathComponent(relativePath)
            let absolutePath = absoluteURL.path
            let remoteURL = destinationURL.appendingPathComponent(relativePath)
            
            if isDir(fileName: absolutePath) {
                
                // Обернуто в функцию, потому, что может потребоваться повторное выполнение
                
                func createFolder() {
                    client.files.createFolderV2(path: remoteURL.path).response {
                        result, error in
                        
                        if error != nil {
                            if case let .rateLimitError(error, _, _, _) = error! {
                                let delay = Int(error.retryAfter)
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: {
                                    createFolder()
                                })
                                
                                return
                            } else {
                                let alert = FilesRelocationTask.failDialog(filename: absoluteURL.lastPathComponent, error: DropboxError(error: error?.generalized)) {
                                    switch $0 {
                                    case .stop:
                                        callback(nil)
                                    case .skip:
                                        ignore = relativePath
                                        completed += 1
                                        progress?(completed / count)
                                        continueRequests()
                                    case .tryAgain:
                                        createFolder()
                                    }
                                }
                                
                                self.view.window!.addSubview(alert.view)
                                return
                            }
                        }
                        completed += 1
                        progress?(completed / count)
                        continueRequests()
                    }
                }
                
                createFolder()
                
            } else {
                
                // Обернуто в функцию, потому, что может потребоваться повторное выполнения
                
                func createFile() {
                    uploadFile(at: absoluteURL, to: remoteURL, callback: { (error) in
                        if let error = error {
                            
                            // Спрашиваем юзера: Что делать?
                            
                            let alert = FilesRelocationTask.failDialog(filename: absoluteURL.lastPathComponent, error: error) {
                                switch $0 {
                                case .stop:
                                    callback(nil)
                                case .skip:
                                    completed += 1
                                    progress?(completed / count)
                                    continueRequests()
                                case .tryAgain:
                                    createFile()
                                }
                            }
                            
                            self.view.window!.addSubview(alert.view)
                            
                            return
                        }
                        completed += 1
                        progress?(completed / count)
                        continueRequests()
                    }, progress: {
                        progress?(($0 + completed) / count)
                    })
                }
                createFile()
            }
            return false
        }
        
        func continueRequests() {
            while nextRequest() {
                completed += 1
                progress?(completed / count)
            }
        }
        
        // Поехали по запросам
        
        continueRequests()
    }
    
    override func receiveFile(file: String, from source: FileSourceType, storedAt localURL: URL, callback: @escaping FilesRelocationCompletion, progress: @escaping (Float) -> ()) {
        
        guard let client = DropboxClientsManager.authorizedClient else { callback(nil); return }
        
        let availableName = getAvailableFileName(fileName: file)
        let destinationURL = url.appendingPathComponent(availableName)
        
        if case .dropbox = source {
            client.files.moveV2(fromPath: localURL.path, toPath: destinationURL.path, allowSharedFolder: true, autorename: true, allowOwnershipTransfer: true).response(completionHandler: { (result, error) in
                callback(DropboxError(error: error?.generalized))
            })
        } else {
            if isDir(fileName: localURL.path) {
                
                uploadFolder(at: localURL, to: destinationURL, callback: { (error) in
                    callback(error)
                }, progress: progress)
            } else {
                
                uploadFile(at: localURL, to: destinationURL, callback: { (error) in
                    if case .local = source {} else {
                        try? FileManager.default.removeItem(at: localURL)
                    }
                    callback(error)
                }, progress: progress)
            }
        }
    }
    
    override func canReceiveFile(file: FSNode, from source: FileSourceType) -> FilesRelocationManager.FileReceiveability {
       
        if isLoading {
            return .no(reason: .loadingIsInProcess)
        }
        
        return .yes
    }
    
    deinit {
        TemproraryFileMetadataManager.clearJunkMetadataForFiles(files: self.files)
        folderLoadingRequest?.cancel()
        folderLoadingRequest = nil
        stopLongpoolRequest()
    }
}

