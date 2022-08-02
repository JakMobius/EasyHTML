import UIKit
import Zip

internal class LocalFileListTableView: FileListController, FileListDataSource, FileListDelegate, LibraryPickerDelegate, FileDetailDelegate, FileDetailDataSource, NewFileDialogDelegate, FileCreationDialogDelegate {

    private var files: [FSNode] = []
    internal var isRoot = true
    internal var shortURL: URL!

    internal override func updateNavigationItemButtons() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createNewFile))
        navigationItem.leftBarButtonItem = nil
    }

    override internal func viewDidLoad() {
        super.viewDidLoad()

        if (shortURL == nil && !isRoot) {
            fatalError("Expected folder path")
        }

        fileListDelegate = self
        fileListDataSource = self

        if (isRoot) {

            shortURL = URL(fileURLWithPath: "")
            url = URL(fileURLWithPath: FileBrowser.filesFullPath)

            title = localize("documents")
        }

        navigationItem.backBarButtonItem = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)

        setupFileListUpdatedNotificationHandling()
        NotificationCenter.default.addObserver(self, selector: #selector(fileMetadataDidChange(_:)), name: .TCFileMetadataChanged, object: nil)

        isLoading = true

        reloadFiles()
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

    var needsUpdate = false

    private func fileListUpdated(sender: NSNotification) {

        if needsUpdate {
            return
        }

        if let userInfo = sender.userInfo {

            let path = userInfo["path"] as? URL

            if path == nil || path! == url {
                if appeared {
                    reloadFiles(animated: true)
                } else {
                    needsUpdate = true
                }
            } else if path!.deletingLastPathComponent() == url {

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

    internal func reloadFiles(animated: Bool = false) {

        DispatchQueue(label: "easyhtml.localfilelist.sortingqueue").async {

            // FileBrowser.getDir may hang for some time as it's sorting the folder contents.
            // This, it should be called in a separate thread

            let newFiles = FileBrowser.getDir(url: self.shortURL)

            DispatchQueue.main.async {

                // self.files should only be updated in a main thread

                let oldFiles: [FSNode]! = animated ? self.files : nil
                self.files = newFiles

                func updateFileList() {
                    self.isLoading = false
                    if animated {
                        self.updateFileListAnimated(old: oldFiles!)
                    } else {
                        self.tableView.reloadData()
                    }
                }

                let isEmpty = self.files.isEmpty

                if self.isLoading && !isEmpty {
                    UIView.transition(with: self.tableView, duration: 0.35, options: .transitionCrossDissolve, animations: {
                        updateFileList()
                    })
                } else {
                    updateFileList()
                }

                if isEmpty {
                    if !self.emptyFolderWarningShown {
                        self.showEmptyFolderWarning()
                    }
                } else {
                    self.hideEmptyFolderWarning()
                }
            }
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

    internal func countOfFiles() -> Int {
        files.count
    }

    internal func fileList(fileForRowAt index: Int) -> FSNode {
        files[index]
    }

    private var previewLoaderQueue = DispatchQueue(label: "easyhtml.filelist.previewloader", qos: .background, attributes: .concurrent)
    private var loadingPreviewImages = [String]()
    private var previewImagesForCells = [String: NSData]()

    internal override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)

        if isLoading {
            return
        }

        let file = files[indexPath.row]
        if let file = file as? FSNode.File {

            if previewImagesForCells.keys.contains(file.name) || loadingPreviewImages.contains(file.name) {
                return
            }

            loadingPreviewImages.append(file.name)

            let ext = file.url.pathExtension

            if Editor.imageExtensions.contains(ext) {
                previewLoaderQueue.async(flags: .barrier) {

                    guard var data = try? Data(contentsOf: self.url.appendingPathComponent(file.name)) else {
                        return
                    }

                    var image = UIImage(data: data as Data)
                    if (image == nil) {
                        return
                    }

                    let width = image!.size.width
                    let height = image!.size.height

                    if width * height * 4 >= 200000000 {
                        return
                    }

                    if (width > 32 || height > 32) {

                        let newImage = image!.resized(to: CGSize(width: 32, height: 32))

                        if let newData = newImage.pngData() {
                            data = newData
                        } else {
                            return
                        }
                    }

                    let imageData = NSData(data: data)
                    image = nil

                    DispatchQueue.main.async {

                        self.previewImagesForCells[file.name] = imageData
                        if let index = self.loadingPreviewImages.firstIndex(of: file.name) {
                            self.loadingPreviewImages.remove(at: index)
                        }

                        self.tableView.reloadRows(at: [indexPath], with: .none)
                    }
                }
            }
        }
    }

    internal override func previewImageFor(file: FSNode, at index: Int) -> UIImage? {

        if let data = previewImagesForCells[file.name], let image = UIImage(data: data as Data) {
            return image
        } else {
            return nil
        }
    }

    func navigateToDirectory(_ directory: FSNode.Folder) {

        // Get cached controller if it exists

        if let controller = fileListManager.getCachedController(for: directory.url, with: sourceType) {
            navigationController?.pushViewController(controller, animated: true)
            return
        }

        let controller = LocalFileListTableView()

        controller.fileListManager = fileListManager
        controller.shortURL = shortURL.appendingPathComponent(directory.name)
        controller.url = url.appendingPathComponent(directory.name)
        controller.isRoot = false
        controller.title = directory.name

        navigationController?.pushViewController(controller, animated: true)
    }

    func openFile(file: FSNode, inNewTab: Bool = false) {
        if (file is FSNode.Folder) {
            navigateToDirectory(file as! FSNode.Folder)
            return
        } else if !fileListManager.isRelocatingFiles {
            let file = file as! FSNode.File

            let e = getFileExtensionFromString(fileName: file.name)
            if (e == "zip" || e == "jar") {
                unarchive(file: file)
                return
            }

            var config: EditorConfiguration = [.ioManager: Editor.IOManager()]

            if inNewTab {
                config[.openInNewTab] = true
            }

            if (Editor.imageExtensions.contains(e)) {
                openAsImage(file: file, config: config)
            } else if (Editor.syntaxHighlightingSchemeFor(ext: e) != nil) {
                openSourceCode(file: file, config: config)
            } else {
                openInBrowser(file: file, config: config)
            }
        }
    }

    func shareFile(at indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {

            let file = files[indexPath.row]
            let objectsToShare = [file.url]
            let activityController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)

            let popover = activityController.popoverPresentationController

            popover?.sourceView = cell
            popover?.sourceRect = cell.bounds

            let instance = PrimarySplitViewController.instance(for: view)!

            instance.present(activityController, animated: true, completion: nil)
        }
    }

    func shortcutActionsForFile(file: FSNode, at index: Int) -> [ContextMenuAction] {
        let indexPath = IndexPath(row: index, section: 0)

        if file is FSNode.Folder {
            return [
                .quickZipAction {
                    _ in
                    let options = ArchivingOptions()
                    options.compressionType = .bestSpeed
                    self.archive(file: file, with: options)
                },
                .shareAction {
                    _ in
                    self.shareFile(at: indexPath)
                },
                .moveAction {
                    _ in
                    self.selectFileToRelocate(at: indexPath)
                }
            ]
        } else if let file = file as? FSNode.File {

            var actions: [ContextMenuAction] = []

            if (file.url.pathExtension != "zip") {
                actions.append(.openInNewTabAction {
                    _ in
                    self.openFile(file: file, inNewTab: true)
                })

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
            }

            actions.append(.shareAction {
                _ in
                self.shareFile(at: indexPath)
            })

            actions.append(.moveAction {
                _ in
                self.selectFileToRelocate(at: indexPath)
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

        let detailController = FileDetailViewController.getNew(observingFile: files[indexPath.row], actions: actions)
        let navigationController = ThemeColoredNavigationController(rootViewController: detailController)

        detailController.delegate = self
        detailController.dataSource = self

        navigationController.modalPresentationStyle = .formSheet

        PrimarySplitViewController.instance(for: view).present(navigationController, animated: true, completion: nil)
    }

    override internal func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 0.01 : 10
    }

    override internal func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    // MARK: NewFileDialog delegate

    func newFileDialog(dialog: NewFileDialog, hasPicked image: UIImage) {
        if let data = image.pngData() {

            let url = url!

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

    internal func fileCreationDialog(controller: FileCreationDialog, createFile named: String, completion: @escaping (FileCreationResult) -> ()) {

        if fileForName(name: named) != nil {
            completion(.filenameUsed)
            return
        }

        let ext = getFileExtensionFromString(fileName: named)
        let data = getFileTemplateDataFromExtension(ext: ext)

        let path = url.appendingPathComponent(named).path
        if FileManager.default.createFile(atPath: path, contents: data, attributes: nil) {

            FileBrowser.fileListUpdatedAt(url: url)
            userPreferences.statistics.filesCreated += 1
            completion(.success)
        } else {
            completion(.other)
        }
    }

    internal func fileCreationDialog(controller: FileCreationDialog, createFolder named: String, completion: @escaping (FileCreationResult) -> ()) {

        if fileForName(name: named) != nil {
            completion(.filenameUsed)
            return
        }

        do {
            let url = url.appendingPathComponent(named)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)

            FileBrowser.fileListUpdatedAt(url: self.url)
            userPreferences.statistics.foldersCreated += 1

            completion(.success)
        } catch {
            completion(.other)
        }
    }

    // MARK: FileListController delegate

    internal func fileList(deleted file: FSNode) {

        try? FileManager.default.removeItem(at: url.appendingPathComponent(file.name))

        FileBrowser.fileListUpdatedAt(url: url)

        if file is FSNode.File {
            userPreferences.statistics.filesDeleted += 1
        } else {
            userPreferences.statistics.foldersDeleted += 1
        }

        Editor.fileDeleted(file: file)
    }

    internal func libraryPicker(didSelect library: Library) {
        let localURL = library.getLocalFileURL()

        let availableName = FileBrowser.getAvailableFileName(fileName: localURL.lastPathComponent, path: url.path)

        do {
            try FileManager.default.copyItem(at: localURL, to: url.appendingPathComponent(availableName))

            FileBrowser.fileListUpdatedAt(url: url)
        } catch {
        }
    }

    func fileDetail(pathTo file: FSNode) -> String {
        shortURL.path
    }

    internal func fileDetail(controller: FileDetailViewController, shouldRename file: FSNode, to newName: String) {

        let fileURL = url.appendingPathComponent(file.name)

        let availableName = FileBrowser.getAvailableFileName(fileName: newName, path: url.path)

        let destinationURL = url.appendingPathComponent(availableName)

        try? FileManager.default.moveItem(at: fileURL, to: destinationURL)

        Editor.fileMoved(file: file, to: url.appendingPathComponent(newName))

        if let fileIndex = files.firstIndex(of: file) {

            let file = files[fileIndex]
            file.url = file.url.deletingLastPathComponent().appendingPathComponent(availableName)

            tableView.reloadRows(at: [IndexPath(row: fileIndex, section: 0)], with: .fade)
        }

        reloadFiles(animated: true)
    }

    internal func fileDetail(controller: FileDetailViewController, shouldClone file: FSNode) {
        cloneFile(file: file)
    }

    internal func cloneFile(file: FSNode) {
        let fileURL = url.appendingPathComponent(file.name)

        var name = FileBrowser.clonedFileName(fileName: file.name)

        name = FileBrowser.getAvailableFileName(fileName: name, path: url.path)

        let alert = NetworkOperationDialog()

        alert.alert.header.text = localize("cloning", .files)

        func clone() {
            alert.operationStarted()

            DispatchQueue(label: "easyhtml.cloningfilequeue", qos: .userInteractive).async {
                do {
                    try FileManager.default.copyItem(at: fileURL, to: self.url.appendingPathComponent(name))

                    DispatchQueue.main.async {
                        alert.operationCompleted()

                        FileBrowser.fileListUpdatedAt(url: self.url)
                    }
                } catch {
                    DispatchQueue.main.async {
                        alert.operationFailed(with: error, retryHandler: {
                            clone()
                        })
                    }
                }
            }

            alert.operationStarted()
        }

        alert.present(on: view.window!)

        clone()
    }

    internal func unarchive(file: FSNode) {
        var newName = file.url.deletingPathExtension().lastPathComponent

        newName = FileBrowser.getAvailableFileName(fileName: newName, path: url.path)

        let newURL = url.appendingPathComponent(newName)

        Zipper.unzipFile(on: view.window!, at: file.url, to: newURL, completion: {
            self.reloadFiles(animated: true)
        })
    }

    internal func archive(file: FSNode, with options: ArchivingOptions) {
        var newName = file.url.appendingPathExtension("zip").lastPathComponent

        newName = FileBrowser.getAvailableFileName(fileName: newName, path: url.path)

        let newURL = url.appendingPathComponent(newName)

        Zipper.zipFile(on: view.window!, at: file.url, to: newURL, compression: options.compressionType, password: options.password ?? "") {
            self.reloadFiles(animated: true)
        }
    }

    internal func fileDetail(controller: FileDetailViewController, shouldUnarchive file: FSNode) {
        unarchive(file: file)
        controller.isDisappeared = true
        controller.dismiss(animated: true, completion: nil)
    }

    internal func fileDetail(controller: FileDetailViewController, shouldArchive file: FSNode, with options: ArchivingOptions) {
        archive(file: file, with: options)

    }

    internal func fileDetail(controller: FileDetailViewController, shouldMove file: FSNode) {

        if let index = files.firstIndex(of: file) {
            selectFileToRelocate(at: IndexPath(row: index, section: 0))
        }
    }

    internal func fileDetail(creationDateOf file: FSNode) -> Date? {
        getFileAttributes(fileName: file.url.path).fileCreationDate()
    }

    internal func fileDetail(modificationDateOf file: FSNode) -> Date? {
        getFileAttributes(fileName: file.url.path).fileModificationDate()
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

    internal func fileDetail(controller: FileDetailViewController, objectsToShare file: FSNode, callback: (Bool, URL) -> ()) {
        callback(false, file.url)
    }

    internal func fileDetail(controller: FileDetailViewController, shouldDelete file: FSNode) {
        fileList(deleted: file)
    }

    override func receiveFile(file: String, from source: FileSourceType, storedAt atURL: URL, callback: @escaping FilesRelocationCompletion, progress: @escaping (Float) -> ()) {

        let availableName = FileBrowser.getAvailableFileName(fileName: file, path: url.path)

        let localURL = url.appendingPathComponent(availableName)

        DispatchQueue.global().async {
            do {
                try FileManager.default.moveItem(atPath: atURL.path, toPath: localURL.path)

                DispatchQueue.main.async {
                    FileBrowser.fileListUpdatedAt(url: self.url)

                    callback(nil)
                }

            } catch {
                DispatchQueue.main.async {
                    callback(error)
                }
            }
        }

    }

    override func prepareToRelocation(file: FSNode, to destination: FileSourceType, completion: @escaping (URL?, Error?) -> (), progress: @escaping (Float) -> ()) {

        completion(file.url, nil)

        FileBrowser.fileListUpdatedAt(url: url)

        if appeared {
            tableView.reloadData()
        } else {
            needsUpdate = true
        }
    }

    override func canReceiveFile(file: FSNode, from source: FileSourceType) -> FilesRelocationManager.FileReceiveAbility {

        if isLoading {
            return .no(reason: .loadingIsInProcess)
        }

        return .yes
    }

    override func didReceiveMemoryWarning() {
        previewImagesForCells = [:]
    }

    deinit {
        TemporaryFileMetadataManager.clearJunkMetadataForFiles(files: files)
    }
}
