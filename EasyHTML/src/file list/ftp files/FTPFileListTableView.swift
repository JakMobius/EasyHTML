import UIKit
import NMSSH

class FTPFileListTableView: FileListController, FileListDelegate, FileListDataSource, NewFileDialogDelegate, FileCreationDialogDelegate, LibraryPickerDelegate {

    internal var session: FTPUniversalSession! = nil
    internal var server: FTPServer! = nil
    override var sourceType: FileSourceType {
        .ftp(server: server)
    }

    internal class FTPIOManager: Editor.IOManager {

        internal struct NoSessionError: Error {
        }

        internal var session: FTPUniversalSession! = nil

        internal override func saveFileAt(url: URL, data: Data, completion: Editor.IOManager.WriteResult) {
            if session == nil {
                completion?(NoSessionError())
                return
            }

            let session = session!

            session.uploadFileAsync(path: url.path, data: data, completion: completion)
        }

        internal override func readFileAt(url: URL, completion: Editor.IOManager.ReadResult, progress: ((Progress) -> ())?) -> CancellableRequest! {
            if session == nil {
                completion?(nil, NoSessionError())
                return nil
            }

            let session = session!

            let progressObject = Progress()
            progressObject.totalUnitCount = 100
            progressObject.completedUnitCount = 0

            var request: CancellableRequest!
            var ftpRequest: CancellableRequest!

            ftpRequest = session.downloadFileAsync(path: url.path, completion: {
                url, error in
                if self.requestCompleted(request) {
                    if let error = error {
                        completion?(nil, error)
                        return
                    }
                    do {
                        let data = try Data(contentsOf: url!)
                        completion?(data, nil)
                        try? FileManager.default.removeItem(at: url!)
                    } catch {
                        completion?(nil, error)
                    }

                }
            }) { (prog) in
                if progress != nil {
                    progressObject.completedUnitCount = Int64(prog * 100)
                    progress!(progressObject)
                }
            }

            request = CancellableRequest {
                request in

                ftpRequest?.cancel()
                self.requestCompleted(request)
            }

            requestStarted(request)

            return request
        }

        deinit {
            //session.destroy()
        }
    }

    var files: [FSNode] = []
    var isRoot = false

    override func viewDidLoad() {

        guard session != nil else {
            fatalError("Expected session")
        }

        navigationItem.backBarButtonItem = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)

        super.viewDidLoad()

        isLoading = true

        fileListDelegate = self
        fileListDataSource = self

        // Although it's remote hosting, it's not Dropbox, which notifies you of every action you take.
        // We have to listen to our own changing events.

        NotificationCenter.default.addObserver(self, selector: #selector(fileMetadataDidChange(_:)), name: .TCFileMetadataChanged, object: nil)

        setupThemeChangedNotificationHandling()
        setupFileListUpdatedNotificationHandling()

        makeReloadable()

        fileRefreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)

        reloadDirectory()
    }

    @objc func refresh() {
        reloadDirectory()
    }

    override func updateNavigationItemButtons() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createNewFile))
        navigationItem.leftBarButtonItem = nil
    }

    @objc func createNewFile() {

        let alert: NewFileDialog

        if fileListManager.isRelocatingFiles {
            alert = NewFileDialog(config: NewFileDialog.Config(
                    canCreateFiles: false,
                    canCreateFolders: true,
                    canImportPhotos: false,
                    canImportLibraries: false
            ))
        } else {
            alert = NewFileDialog(config: NewFileDialog.Config(
                    canCreateFiles: true,
                    canCreateFolders: true,
                    canImportPhotos: true,
                    canImportLibraries: true
            ))
        }

        alert.window = view.window
        alert.delegate = self
        alert.fileCreationDelegate = self
        alert.libraryPickerDelegate = self

        view.window!.addSubview(alert.alert.view)
    }

    @objc internal func fileMetadataDidChange(_ notification: NSNotification) {
        if isCurrentViewController, let userInfo = notification.userInfo, let file = userInfo["file"] as? FSNode {

            let folderURL = file.url.deletingLastPathComponent()

            if folderURL == url, let index = files.firstIndex(of: file) {
                let i = files.startIndex.distance(to: index)

                tableView.reloadRows(at: [IndexPath(row: i, section: 0)], with: .none)
            }
        }
    }

    private func fileListUpdated(sender: NSNotification) {

        if needsUpdate {
            return
        }

        if let userInfo = sender.userInfo, let path = userInfo["path"] as? URL? {

            if path == nil || path == url {
                if appeared {
                    reloadDirectory(animated: true)
                } else {
                    needsUpdate = true
                }
            }
        }
    }

    var loadingRequest: CancellableRequest! = nil

    internal func reloadDirectory(animated: Bool = false) {
        loadingRequest = session.listDirectoryAsync(path: url.path, sort: true) {
            result, error in
            self.loadingRequest = nil

            if let result = result {

                self.isLoading = false

                if !animated {
                    self.files = result

                    if self.fileRefreshControl?.isRefreshing == true {
                        self.tableView.reloadData()
                        self.fileRefreshControl.endRefreshing()
                    } else {
                        UIView.transition(with: self.tableView, duration: 0.35, options: .transitionCrossDissolve, animations: {
                            self.tableView.reloadData()
                        })
                    }
                } else {
                    let oldFiles = self.files
                    self.files = result
                    self.updateFileListAnimated(old: oldFiles)
                    self.fileRefreshControl.endRefreshing()
                }

                if self.files.isEmpty {
                    if (!self.emptyFolderWarningShown) {
                        self.showEmptyFolderWarning()
                    }
                } else {
                    self.hideEmptyFolderWarning()
                }
            } else {
                self.fileRefreshControl.endRefreshing()

                if (!self.isLoading) {
                    return
                }
                self.isLoading = false

                self.showErrorLabel(text: error?.localizedDescription)
            }
        }
    }

    private var appeared = false
    private var needsUpdate = false

    internal func reloadFilesIfNeeded() {
        if needsUpdate {
            reloadDirectory(animated: true)
            needsUpdate = false
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        loadingRequest?.cancel()
        appeared = false
    }

    override func viewDidAppear(_ animated: Bool) {
        appeared = true

        reloadFilesIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        reloadFilesIfNeeded()
    }

    func fileList(fileForRowAt index: Int) -> FSNode {
        files[index]
    }

    func countOfFiles() -> Int {
        files.count
    }

    internal func navigateTo(directory: FTPFolder) {

        // Get cached controller if it exists

        if let controller = fileListManager.getCachedController(for: directory.url, with: sourceType) {
            navigationController?.pushViewController(controller, animated: true)
            return
        }

        let controller = FTPFileListTableView()

        controller.url = directory.url
        controller.fileListManager = fileListManager
        controller.session = session
        controller.server = server
        controller.title = directory.url.lastPathComponent

        navigationController?.pushViewController(controller, animated: true)
    }

    internal func openFile(_ file: FSNode, inNewTab: Bool = false) {
        if let folder = file as? FTPFolder {
            navigateTo(directory: folder)
        } else if !fileListManager.isRelocatingFiles, let file = file as? FTPFile {
            let e = getFileExtensionFromString(fileName: file.name)

            if e == "zip" || e == "rar" {
                FileListController.presentRemoteUnarchiveWarning(on: view.window!)
                return
            }

            let config: EditorConfiguration = [.openInNewTab: inNewTab]

            if (Editor.imageExtensions.contains(e)) {
                openAsImage(file: file, config: config)
            } else if (Editor.syntaxHighlightingSchemeFor(ext: e) != nil) {
                openSourceCode(file: file, config: config)
            } else {
                openInBrowser(file: file, config: config)
            }
        }
    }

    private func filterConfig(_ config: EditorConfiguration?) -> EditorConfiguration? {

        let ioManager = FTPIOManager()
        ioManager.session = session.copy() as? FTPUniversalSession

        if config == nil {
            return [.ioManager: ioManager]
        }

        var config = config

        config![.ioManager] = ioManager

        return config
    }

    override func openAsImage(file: FSNode.File, config: EditorConfiguration? = nil) {
        super.openAsImage(file: file, config: filterConfig(config))
    }

    override func openInBrowser(file: FSNode.File, config: EditorConfiguration? = nil, force: Bool = false) {
        super.openInBrowser(file: file, config: filterConfig(config), force: force)
    }

    override func openSourceCode(file: FSNode.File, config: EditorConfiguration? = nil) {
        super.openSourceCode(file: file, config: filterConfig(config))
    }

    override func lightPreviewImageFor(file: FSNode, at index: Int) -> UIImage! {
        if file is FTPShortcut {
            return FilePreviewImages.linkImage
        }

        return nil
    }

    override func previewImageFor(file: FSNode, at index: Int) -> UIImage? {
        if file is FTPShortcut {
            if userPreferences.currentTheme.isDark {
                return FilePreviewImages.linkImageInverted
            } else {
                return FilePreviewImages.linkImage
            }
        }

        return nil
    }

    func openSymlink(_ symlink: FTPShortcut, completion: @escaping (FSNode) -> ()) {
        let alert = NetworkOperationDialog()

        alert.alert.header.text = localize("opening_symlink")

        func getSymlink() {
            alert.operationStarted()
            alert.alert.buttons.first!.isEnabled = false

            session.getSymlinkTarget(path: symlink.url.path) { (result, error) in
                if let result = result {

                    self.session.infoForFileAt(path: result) { (result, error) in
                        if let result = result {
                            alert.operationCompleted()

                            completion(result)

                        } else {

                            var description = localize("failedtogettargetfile")

                            if let error = error {
                                description += "\n" + error.localizedDescription
                            }

                            alert.operationFailed(with: description, retryHandler: {
                                getSymlink()
                            })
                        }
                    }
                } else {
                    alert.operationFailed(with: error, retryHandler: {
                        getSymlink()
                    })
                }
            }

            alert.operationStarted()
        }

        getSymlink()

        alert.present(on: view.window!)
    }

    func fileList(selectedFileAt index: Int) {

        let file = files[index]

        if let symlink = file as? FTPShortcut {

            openSymlink(symlink) {
                if let file = $0 as? FTPFile {
                    self.openFile(file)
                } else if let folder = $0 as? FTPFolder {
                    self.navigateTo(directory: folder)
                }
            }

            return
        }

        openFile(file)
    }

    func fileList(deleted file: FSNode) {
        let alert = NetworkOperationDialog()

        alert.alert.header.text = localize("deleting")

        let label = UILabel(frame: CGRect(x: 0, y: 25, width: 250, height: 15))
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor(white: 0.6, alpha: 1.0)
        label.textAlignment = .center

        alert.activityIndicator.transform = CGAffineTransform(translationX: 0, y: -10)

        func startRequest() {
            alert.operationStarted()
            alert.alert.contentView.addSubview(label)

            var request: CancellableRequest!

            if let folder = file as? FTPFolder {

                let localizedStringCounting = localize("countingfiles", .files)
                let localizedStringDeleting = localize("deletingfiles", .files)

                request = session.deleteFolderRecursivelyAsync(folder: folder, progress: { state in
                    switch state {
                    case .countingFiles(let counted):
                        label.text = localizedStringCounting.replacingOccurrences(of: "#", with: String(counted))
                    case .deletingFiles(let deleted, let total):
                        label.text = localizedStringDeleting
                                .replacingOccurrences(of: "#1", with: String(deleted))
                                .replacingOccurrences(of: "#2", with: String(total))

                        alert.setProgress(Float(deleted) / Float(total))
                    }
                }, completion: { error in

                    label.text = ""
                    label.isHidden = true

                    if let error = error {

                        alert.operationFailed(with: error, retryHandler: {
                            startRequest()
                        })
                    } else {
                        alert.operationCompleted()

                        userPreferences.statistics.foldersDeleted += 1

                        self.reloadDirectory(animated: true)

                        Editor.fileDeleted(file: file)
                    }
                })
            } else {
                request = session.deleteFileAsync(file: file) {
                    error in
                    if let error = error {
                        alert.operationFailed(with: error, retryHandler: {
                            startRequest()
                        })
                    } else {
                        alert.operationCompleted()
                        userPreferences.statistics.filesDeleted += 1
                        self.reloadDirectory(animated: true)

                        Editor.fileDeleted(file: file);
                    }
                }
            }

            alert.cancelHandler = {
                request?.cancel()
            }
        }

        alert.present(on: view.window!)

        startRequest()
    }

    override func fileLongTouched(at index: Int) {

        let file = files[index]

        if let folder = file as? FTPShortcut {
            openSymlink(folder) { (result) in

                guard let file = result as? FTPFile else {
                    self.navigateTo(directory: result as! FTPFolder)
                    return
                }

                var actions: [ContextMenuAction] = [
                    .openInNewTabAction {
                        _ in
                        self.openFile(file, inNewTab: true)
                    }
                ]

                let scheme = Editor.syntaxHighlightingSchemeFor(ext: file.url.pathExtension)

                if scheme == nil {
                    actions.append(.showSourceAction {
                        _ in
                        self.openSourceCode(file: file)
                    })
                } else {
                    actions.append(.showContentAction {
                        _ in
                        self.openInBrowser(file: file, config: nil, force: true)
                    })
                }

                actions.append(ContextMenuAction(title: localize("cm_deletefile"), style: .destructive, callback: { (action) in
                    self.deleteFile(at: index, file: file)
                }))

                actions.append(ContextMenuAction(title: localize("cm_deletelink"), style: .destructive, callback: { (action) in
                    self.deleteFile(at: index)
                }))

                self.openContextMenu(file: file, actions: actions, at: IndexPath(row: index, section: 0), addDeleteButton: false)
            }
        } else {
            super.fileLongTouched(at: index)
        }
    }

    func shortcutActionsForFile(file: FSNode, at index: Int) -> [ContextMenuAction] {
        let indexPath = IndexPath(row: index, section: 0)
        let file = files[index]

        if file is FTPFolder {

            return [
                .moveAction {
                    _ in
                    self.selectFileToRelocate(at: indexPath)
                }
            ]
        } else if let file = file as? FTPFile {

            var actions: [ContextMenuAction] = [
                .openInNewTabAction {
                    _ in
                    self.openFile(file, inNewTab: true)
                }
            ]

            let scheme = Editor.syntaxHighlightingSchemeFor(ext: file.url.pathExtension)

            if scheme == nil {
                actions.append(.showSourceAction {
                    _ in
                    self.openSourceCode(file: file)
                })
            } else {
                actions.append(.showContentAction {
                    _ in
                    self.openInBrowser(file: file, config: nil, force: true)
                })
            }

            actions.append(.moveAction {
                _ in
                self.selectFileToRelocate(at: indexPath)
            })

            return actions
        }

        return []
    }

    internal func fileForName(name: String) -> FSNode! {
        for file in files where file.name == name {
            return file
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
            if (index == 0) {
                name = fileName
            } else {
                name = "\(components[0]) \(index)\(ext)"
            }

            index += 1

        } while fileForName(name: name) != nil

        return name
    }

    func newFileDialog(dialog: NewFileDialog, hasPicked image: UIImage) {

        let data = image.pngData()

        let alert = NetworkOperationDialog()

        alert.alert.header.text = localize("uploadingphoto", .files)

        func startRequest() {
            alert.operationStarted()

            let availableFileName = getAvailableFileName(fileName: "image.png")

            let request = session.uploadFileAsync(path: url.appendingPathComponent(availableFileName).path, data: data!, completion: {
                error in
                if error == nil {
                    alert.operationCompleted()

                    self.reloadDirectory(animated: true)
                } else {
                    alert.operationFailed(with: error, retryHandler: {
                        startRequest()
                    })
                }
            }, progress: {
                progress in
                alert.setProgress(progress)
            })

            alert.cancelHandler = {
                request?.cancel()
            }
        }

        alert.present(on: view.window!)

        startRequest()

    }

    func fileCreationDialog(controller: FileCreationDialog, createFile named: String, completion: @escaping (FileCreationResult) -> ()) {

        if fileForName(name: named) != nil {
            completion(.filenameUsed)
            return
        }

        //if session.proto == .ftp && named.data(using: .ascii) == nil {
        //    completion(.wrongName)
        //    return
        //}

        let ext = getFileExtensionFromString(fileName: named)
        let data = getFileTemplateDataFromExtension(ext: ext) ?? "".data(using: .utf8)!

        session.uploadFileAsync(path: url.appendingPathComponent(named).path, data: data, completion: { error in
            if error == nil {
                completion(.success)
                userPreferences.statistics.filesCreated += 1
            } else {
                completion(.other)
            }

            self.reloadDirectory(animated: true)
        })
    }

    func fileCreationDialog(controller: FileCreationDialog, createFolder named: String, completion: @escaping (FileCreationResult) -> ()) {
        if fileForName(name: named) != nil {
            completion(.filenameUsed)
            return
        }

        if named.data(using: .ascii) == nil {
            completion(.wrongName)
            return
        }

        session.createFolderAsync(path: url.appendingPathComponent(named).path) { error in
            if error == nil {
                completion(.success)
                userPreferences.statistics.foldersCreated += 1
            } else {
                completion(.other)
            }

            self.reloadDirectory(animated: true)
        }
    }

    private func uploadFolder(at localURL: URL, to destinationURL: URL, callback: @escaping (Error?) -> (), progress: ((Float) -> ())? = nil) {

        // Almost identical to uploadFolder method from DropboxFileListTableView

        let separateItemProgress: Float
        var currentProgress: Float = 0
        var subpaths: IndexingIterator<[String]>
        do {
            var paths = try FileManager.default.subpathsOfDirectory(atPath: localURL.path)
            separateItemProgress = 1 / Float(paths.count + 1)
            paths.insert("", at: 0)
            subpaths = paths.makeIterator()
        } catch {
            callback(error)
            return
        }

        func nextRequest() {

            guard let relativePath = subpaths.next() else {
                callback(nil)
                return
            }

            let absoluteURL = localURL.appendingPathComponent(relativePath)
            let absolutePath = absoluteURL.path
            let remoteURL = destinationURL.appendingPathComponent(relativePath)

            if isDir(fileName: absolutePath) {

                // This code is wrapped in a function, as we might want to call it several times

                func createFolder() {

                    session.createFolderAsync(path: remoteURL.path, completion: { (error) in
                        if error != nil {
                            let alert = FilesRelocationTask.failDialog(filename: absoluteURL.lastPathComponent, error: error) {
                                switch $0 {
                                case .stop:
                                    callback(nil)
                                case .skip:
                                    nextRequest()
                                case .tryAgain:
                                    createFolder()
                                }
                            }

                            self.view.window!.addSubview(alert.view)
                        } else {
                            currentProgress += separateItemProgress
                            progress?(currentProgress)
                            nextRequest()
                        }
                    })
                }

                createFolder()

            } else {

                // This code is wrapped in a function, as we might want to call it several times
                func createFile() {

                    func errorHandler(restoreType: RelocationErrorRestoreType) {
                        switch restoreType {
                        case .stop:
                            callback(nil)
                        case .skip:
                            nextRequest()
                        case .tryAgain:
                            createFile()
                        }
                    }

                    guard let inputStream = InputStream(url: absoluteURL) else {
                        let alert = FilesRelocationTask.failDialog(filename: absoluteURL.lastPathComponent, error: FileRelocationError.couldNotReadFile, callback: errorHandler)
                        view.window!.addSubview(alert.view)
                        return
                    }

                    session.uploadFileAsync(path: remoteURL.path, input: inputStream, completion: {
                        error in
                        if let error = error {

                            // Ask user what to do
                            let alert = FilesRelocationTask.failDialog(filename: absoluteURL.lastPathComponent, error: error, callback: errorHandler)
                            self.view.window!.addSubview(alert.view)
                            return
                        }
                        currentProgress += separateItemProgress
                        progress?(currentProgress)
                        nextRequest()
                    })
                }

                createFile()
            }
        }

        nextRequest()
    }

    private func uploadLibrary(library: Library) {
        let localURL = library.getLocalFileURL()

        let alert = NetworkOperationDialog()
        alert.alert.header.text = localize("uploadinglibrary", .files)

        func startRequest() {
            alert.operationStarted()

            let path = url.appendingPathComponent(getAvailableFileName(fileName: library.name + library.ext)).path

            guard let stream = InputStream(fileAtPath: localURL.path) else {
                alert.operationFailed(with: FileRelocationError.couldNotReadFile, retryHandler: {
                    startRequest()
                })
                return
            }

            let size = Float(getFileItemSize(at: localURL.path))

            let request = session.uploadFileAsync(path: path, input: stream, completion: { error in
                if error == nil {
                    alert.operationCompleted()

                    self.reloadDirectory(animated: true)
                } else {
                    alert.operationFailed(with: error, retryHandler: {
                        startRequest()
                    })
                }
            }, progress: {
                bytesWritten in

                let progress = Float(bytesWritten) / size

                alert.setProgress(progress, animated: true)
            })

            alert.cancelHandler = {
                request?.cancel()
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

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let file = files[indexPath.row]

        let actions: [FileDetailViewController.Action] = [.clone, .delete, .move, .rename]

        let detailController = FileDetailViewController.getNew(observingFile: file, actions: actions)
        let navigationController = ThemeColoredNavigationController(rootViewController: detailController)

        detailController.delegate = self
        detailController.dataSource = self

        navigationController.modalPresentationStyle = .formSheet

        PrimarySplitViewController.instance(for: view).present(navigationController, animated: true, completion: nil)
    }

    func cloneFile(file: FSNode) {
        let alert = NetworkOperationDialog()
        alert.alert.header.text = localize("cloning", .files)

        func startRequest() {
            alert.operationStarted()

            let availableName = getAvailableFileName(fileName: FileBrowser.clonedFileName(fileName: file.name))

            let path = url.appendingPathComponent(availableName).path

            var request: CancellableRequest!

            if let file = file as? FTPFile {

                alert.activityIndicator.transform = .identity

                request = session.copyFileAsync(file: file, to: path, completion: {
                    error in
                    if error == nil {
                        alert.operationCompleted()
                        self.reloadDirectory(animated: true)
                    } else {
                        alert.operationFailed(with: error, retryHandler: {
                            startRequest()
                        })
                    }
                }, progress: {
                    progress in
                    alert.setProgress(progress)
                })
            } else if let folder = file as? FTPFolder {

                alert.activityIndicator.transform = CGAffineTransform(translationX: 0, y: -10)

                let localizedStringCounting = localize("countingfiles", .files)
                let localizedStringCopying = localize("copyingfiles", .files)

                let label = UILabel(frame: CGRect(x: 0, y: 25, width: 250, height: 15))
                label.font = UIFont.systemFont(ofSize: 12)
                label.textColor = UIColor(white: 0.6, alpha: 1.0)
                label.textAlignment = .center

                alert.alert.contentView.addSubview(label)

                request = session.copyFolderRecursivelyAsync(folder: folder, to: path, progress: { state in
                    switch state {
                    case .copyingFiles(let copied, let total):
                        label.text = localizedStringCopying
                                .replacingOccurrences(of: "#1", with: String(copied))
                                .replacingOccurrences(of: "#2", with: String(total))
                        alert.setProgress(Float(copied) / Float(total))
                    case .countingFiles(let counted):
                        label.text = localizedStringCounting.replacingOccurrences(of: "#", with: String(counted))
                    }
                }, errorHandler: {
                    error, callback in

                    let alert = TCAlertController.getNew()

                    alert.applyDefaultTheme()

                    alert.contentViewHeight = 50
                    alert.constructView()

                    alert.addTextView().text = error.localizedDescription

                    alert.header.text = localize("copyingerror")

                    alert.addAction(action: TCAlertAction(text: localize("tryagain"), action: { (_, _) in
                        callback(.tryAgain)
                    }, shouldCloseAlert: true))
                    alert.addAction(action: TCAlertAction(text: localize("skipfile"), action: { (_, _) in
                        callback(.skip)
                    }, shouldCloseAlert: true))
                    alert.addAction(action: TCAlertAction(text: localize("stopcopying"), action: { (_, _) in
                        callback(.stop)
                    }, shouldCloseAlert: true))

                    view.window!.addSubview(alert.view)

                }, completion: { error in
                    label.removeFromSuperview()

                    if let error = error {
                        alert.operationFailed(with: error, retryHandler: {
                            startRequest()
                        })
                    } else {
                        alert.operationCompleted()
                        self.reloadDirectory(animated: true)
                    }
                })
            }

            alert.cancelHandler = {
                request?.cancel()
            }
        }

        alert.present(on: view.window!)

        startRequest()
    }

    override func canReceiveFile(file: FSNode, from source: FileSourceType) -> FilesRelocationManager.FileReceiveAbility {

        if isLoading {
            return .no(reason: .loadingIsInProcess)
        }

        return .yes
    }

    override func prepareToRelocation(file: FSNode, to destination: FileSourceType, completion: @escaping (URL?, Error?) -> (), progress: @escaping (Float) -> ()) {

        if destination == sourceType {
            if let index = files.firstIndex(of: file) {
                files.remove(at: index)
                if appeared {
                    tableView.reloadData()
                } else {
                    needsUpdate = true
                }
            }
        }

        if case .ftp(let server) = destination {
            if server == self.server {
                completion(file.url, nil)
                return
            }
        }

        var tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        tempURL.appendPathComponent(UUID().uuidString)

        func processLink(symlink: FTPShortcut) {
            session.getSymlinkTarget(path: symlink.url.path) { (result, error) in
                if let result = result {
                    self.session.infoForFileAt(path: result, completion: { (result, error) in
                        if let result = result {
                            if let file = result as? FTPFile {
                                processFile(file: file)
                            } else if let folder = result as? FTPFolder {
                                processFolder(folder: folder)
                            }
                        }
                    })
                }
            }
        }

        func processFile(file: FSNode) {
            session.downloadFileAsync(path: file.url.path, completion: { (url, error) in
                completion(url, error)
            }, progress: {
                prog in

                progress(prog)
            })
        }

        func processFolder(folder: FTPFolder) {

            func errorOccurred(error: Error!, callback: @escaping (RelocationErrorRestoreType) -> ()) {

                let alert = TCAlertController.getNew()

                alert.applyDefaultTheme()
                alert.contentViewHeight = 50
                alert.constructView()

                alert.addTextView().text = error.localizedDescription
                alert.header.text = localize("copyingerror")

                alert.addAction(action: TCAlertAction(text: localize("tryagain"), action: { (_, _) in
                    callback(.tryAgain)
                }, shouldCloseAlert: true))
                alert.addAction(action: TCAlertAction(text: localize("skipfile"), action: { (_, _) in
                    callback(.skip)
                }, shouldCloseAlert: true))
                alert.addAction(action: TCAlertAction(text: localize("stopcopying"), action: { (_, _) in
                    callback(.stop)
                }, shouldCloseAlert: true))

                view.window!.addSubview(alert.view)
            }

            session.downloadFolder(folder: folder, to: tempURL.path, errorHandler: errorOccurred, completion: { (error) in
                if error == nil {
                    completion(tempURL, nil)
                } else {
                    completion(nil, error)
                }
            }, progress: progress)
        }

        if let file = file as? FTPFile {
            processFile(file: file)
        } else if let folder = file as? FTPFolder {
            processFolder(folder: folder)
        } else if let symlink = file as? FTPShortcut {
            processLink(symlink: symlink)
        }
    }

    override func receiveFile(file: String, from source: FileSourceType, storedAt localUrl: URL, callback: @escaping FilesRelocationCompletion, progress: @escaping (Float) -> ()) {

        let isFolder = isDir(fileName: localUrl.path)

        let availableName = getAvailableFileName(fileName: file)
        let destinationURL = url.appendingPathComponent(availableName)

        if case .ftp(let server) = source {
            if server == self.server {
                session.moveFileAsync(file: localUrl.path, isDirectory: isFolder, to: destinationURL.path, errorHandler: {
                    error, callback in

                    let alert = TCAlertController.getNew()

                    alert.applyDefaultTheme()

                    alert.contentViewHeight = 50
                    alert.constructView()

                    alert.addTextView().text = error.localizedDescription

                    alert.header.text = localize("copyingerror")

                    alert.addAction(action: TCAlertAction(text: localize("tryagain"), action: { (_, _) in
                        callback(.tryAgain)
                    }, shouldCloseAlert: true))
                    alert.addAction(action: TCAlertAction(text: localize("skipfile"), action: { (_, _) in
                        callback(.skip)
                    }, shouldCloseAlert: true))
                    alert.addAction(action: TCAlertAction(text: localize("stopcopying"), action: { (_, _) in
                        callback(.stop)
                    }, shouldCloseAlert: true))

                    view.window!.addSubview(alert.view)
                }, completion: {
                    error in
                    callback(error)
                    if error == nil {
                        self.reloadDirectory(animated: true)
                    }
                })
                return
            }
        }

        if isFolder {
            uploadFolder(at: localUrl, to: destinationURL, callback: { (error) in
                if error == nil {
                    self.reloadDirectory(animated: true)
                }
                if source != FileSourceType.local {
                    try? FileManager.default.removeItem(at: localUrl)
                }
                callback(error)
            }, progress: {
                progress($0)
            })
        } else {
            guard let inputStream = InputStream(fileAtPath: localUrl.path) else {
                return
            }

            guard let attributes = try? FileManager.default.attributesOfItem(atPath: localUrl.path) else {
                return
            }

            let size = (attributes[FileAttributeKey.size] as! NSNumber).floatValue

            session.uploadFileAsync(path: destinationURL.path, input: inputStream, completion: {
                error in
                if error == nil {
                    self.reloadDirectory(animated: true)
                }
                if source != FileSourceType.local {
                    try? FileManager.default.removeItem(at: localUrl)
                }
                callback(error)
            }, progress: {
                progress(Float($0) / size)
            })
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        TemporaryFileMetadataManager.clearJunkMetadataForFiles(files: files)

        if isRoot {
            session.destroy()
        }
    }
}
