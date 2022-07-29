//
//  FileListController.swift
//  EasyHTML
//
//  Created by Артем on 06.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

internal class FileListController: BasicMasterController, UIGestureRecognizerDelegate, UITextViewDelegate, SharedFileContainer {

    static func presentRemoteUnarchiveWarning(on view: UIView) {
        let alert = TCAlertController.getNew()

        alert.applyDefaultTheme()
        alert.contentViewHeight = 50
        alert.constructView()
        alert.header.text = localize("unarchivingerror")
        alert.addTextView().text = localize("cannotunzipremotefile")
        alert.addAction(action: TCAlertAction(text: "OK", shouldCloseAlert: true))
        alert.makeCloseableByTapOutside()

        view.addSubview(alert.view)
    }

    @available(*, deprecated, message: "Consider using showErrorLabel(text:)")

    func presentFolderReadError(description: String?, reload: @escaping () -> ()) {
        let alert = TCAlertController.getNew()

        alert.applyDefaultTheme()
        alert.minimumButtonsForVerticalLayout = 1

        alert.contentViewHeight = 70
        alert.constructView()
        alert.headerText = localize("foldererror", .files)

        var message = localize("foldererrordesc", .files)

        if let description = description {
            message += "\n" + description
        }

        let textView = alert.addTextView()
        textView.text = message

        alert.animation = TCAnimation(animations: [TCAnimationType.scale(0.8, 0.8), TCAnimationType.opacity], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.6)
        alert.closeAnimation = alert.animation

        alert.addAction(action: TCAlertAction(text: localize("close"), action: {
            _, _ in
            self.navigationController?.popViewController(animated: true)
        }, shouldCloseAlert: true))
        alert.addAction(action: TCAlertAction(text: localize("tryagain"), action: { (_, _) in
            reload()
        }, shouldCloseAlert: true))

        view.window!.addSubview(alert.view)
    }

    internal var fileListManager: FileListManager! = nil
    internal weak var fileListDataSource: FileListDataSource! = nil
    internal weak var fileListDelegate: FileListDelegate! = nil
    private(set) var fileRefreshControl: UIRefreshControl!
    internal var url: URL!
    internal var isMovingSourceFolder = false

    public var isCurrentViewController: Bool {
        if let nc = navigationController, nc.viewControllers.last != self {
            return false
        }

        return true
    }

    public func makeReloadable() {
        if fileRefreshControl != nil {
            return
        }

        fileRefreshControl = UIRefreshControl()

        if #available(iOS 10.0, *) {
            tableView.refreshControl = fileRefreshControl
        } else {
            tableView.addSubview(fileRefreshControl)
        }
    }

    override internal func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0.01
    }

    override internal func viewDidLoad() {
        super.viewDidLoad()

        guard fileListManager != nil else {
            fatalError("[EasyHTML] [FileListController] Must set fileListManager before presenting controller")
        }

        tableView.register(UINib(nibName: "FileListCell", bundle: nil), forCellReuseIdentifier: "cell")
        tableView.register(UINib(nibName: "FileListPlaceholderCell", bundle: nil), forCellReuseIdentifier: "placeholdercell")

        if #available(iOS 11.0, *) {
            tableView.dragDelegate = self
            tableView.dropDelegate = self
        } else {
            // Fallback on earlier versions
        }

        setupToolBar()

        updateStyle()

        updateNavigationItemButtons()

        clearsSelectionOnViewWillAppear = true

        if url != nil && !url.absoluteString.hasSuffix("/") {
            url.appendPathComponent("/")
        }

        setupThemeChangedNotificationHandling()

        edgesForExtendedLayout = []
    }

    internal func updateFileListAnimated(old: [FSNode]) {

        guard fileListDataSource != nil else {
            fatalError("[EasyHTML] [FileListController] -updateFileListAnimated: Must set fileListDataSource before calling related methods")
        }

        var newFiles = [FSNode]()

        tableView.beginUpdates()

        for i in 0..<fileListDataSource!.countOfFiles() {
            newFiles.append(fileListDataSource!.fileList(fileForRowAt: i))
        }


        for (i, file) in old.enumerated() {

            if !newFiles.contains(where: { nfile -> Bool in nfile.name == file.name }) {
                tableView.deleteRows(at: [IndexPath(row: i, section: 0)], with: .left)
            }
        }

        func index(of file: FSNode, in files: [FSNode]) -> Int! {
            for (i, f) in files.enumerated() where f.name == file.name {
                return i
            }
            return nil
        }

        for (i, file) in newFiles.enumerated() {
            let findex = index(of: file, in: old)
            if findex == nil {
                tableView.insertRows(at: [IndexPath(row: i, section: 0)], with: .top)
            } else if findex != i {
                tableView.moveRow(at: IndexPath(row: findex!, section: 0), to: IndexPath(row: i, section: 0))
            }
        }

        tableView.endUpdates()

        updateCellColors()
    }

    override func updateTheme() {
        super.updateTheme()

        view.backgroundColor = userPreferences.currentTheme.background
        emptyFolderTopLabel?.textColor = userPreferences.currentTheme.secondaryTextColor
        updateToolBar()

    }

    internal override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if presentedViewController != nil {
            scrollView.panGestureRecognizer.isEnabled = false;
            scrollView.panGestureRecognizer.isEnabled = true;
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        }

        if _isLoading {
            scrollView.panGestureRecognizer.isEnabled = false;
            scrollView.panGestureRecognizer.isEnabled = true;
        }
    }

    private var emptyFolderTopLabel: UILabel! = nil
    private var emptyFolderBottomLabel: UILabel! = nil

    internal override func scrollViewDidScroll(_ scrollView: UIScrollView) {

        super.scrollViewDidScroll(scrollView)

        updateProgressView()

        if emptyFolderWarningShown {

            var transformTop = scrollView.contentOffset.y * 0.4
            let transformBottom = scrollView.contentOffset.y * 0.25

            let delta = transformTop - transformBottom

            if delta >= 15 {
                transformTop -= delta - 15
            }

            emptyFolderTopLabel?.transform = CGAffineTransform(translationX: 0, y: transformTop)
            emptyFolderBottomLabel?.transform = CGAffineTransform(translationX: 0, y: transformBottom)
        }
    }

    internal var emptyFolderWarningShown: Bool {
        get {
            emptyFolderTopLabel != nil
        }
    }

    internal func showEmptyFolderWarning() {
        if emptyFolderTopLabel == nil && emptyFolderBottomLabel == nil {
            emptyFolderTopLabel = UILabel()
            emptyFolderBottomLabel = UILabel()

            emptyFolderTopLabel.translatesAutoresizingMaskIntoConstraints = false
            emptyFolderBottomLabel.translatesAutoresizingMaskIntoConstraints = false

            emptyFolderTopLabel.textAlignment = .center
            emptyFolderBottomLabel.textAlignment = .center

            view.addSubview(emptyFolderTopLabel)
            view.addSubview(emptyFolderBottomLabel)

            tableView.centerXAnchor.constraint(equalTo: emptyFolderTopLabel.centerXAnchor).isActive = true
            tableView.centerYAnchor.constraint(equalTo: emptyFolderTopLabel.centerYAnchor, constant: 60).isActive = true
            emptyFolderTopLabel.widthAnchor.constraint(lessThanOrEqualTo: tableView.widthAnchor, constant: -100).isActive = true

            tableView.centerXAnchor.constraint(equalTo: emptyFolderBottomLabel.centerXAnchor).isActive = true
            emptyFolderBottomLabel.topAnchor.constraint(equalTo: emptyFolderTopLabel.bottomAnchor, constant: 20).isActive = true
            emptyFolderBottomLabel.widthAnchor.constraint(lessThanOrEqualTo: tableView.widthAnchor, constant: -100).isActive = true
            emptyFolderTopLabel.bottomAnchor.constraint(equalTo: tableView.bottomAnchor).isActive = true

            emptyFolderTopLabel.text = localize("emptyfolder", .files)
            emptyFolderTopLabel.textColor = userPreferences.currentTheme.secondaryTextColor
            emptyFolderTopLabel.font = .systemFont(ofSize: 25)
            emptyFolderBottomLabel.text = localize("emptyfolderhint", .files)
            emptyFolderBottomLabel.textColor = .gray
            emptyFolderBottomLabel.numberOfLines = 0
            emptyFolderBottomLabel.font = .systemFont(ofSize: 15)

            emptyFolderBottomLabel.alpha = 0
            emptyFolderTopLabel.alpha = 0

            emptyFolderBottomLabel.transform = CGAffineTransform(translationX: 0, y: 20)
            emptyFolderTopLabel.transform = CGAffineTransform(translationX: 0, y: 20)

            UIView.animate(withDuration: 0.5, delay: 0.2, options: [.curveEaseOut], animations: {
                self.emptyFolderTopLabel.alpha = 1.0
                self.emptyFolderTopLabel.transform = .identity
            }, completion: nil)
            UIView.animate(withDuration: 0.5, delay: 0.4, options: [.curveEaseOut], animations: {
                self.emptyFolderBottomLabel.alpha = 1.0
                self.emptyFolderBottomLabel.transform = .identity
            }, completion: nil)
        }
    }

    internal func hideEmptyFolderWarning() {

        guard let topLabel = emptyFolderTopLabel else {
            return
        }
        emptyFolderTopLabel = nil

        guard let bottomLabel = emptyFolderBottomLabel else {
            return
        }
        emptyFolderBottomLabel = nil

        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveEaseIn], animations: {
            topLabel.alpha = 0.0
            topLabel.transform = topLabel.transform.translatedBy(x: 0, y: -20)
        }, completion: nil)
        UIView.animate(withDuration: 0.5, delay: 0.2, options: [.curveEaseIn], animations: {
            bottomLabel.alpha = 0.0
            bottomLabel.transform = topLabel.transform.translatedBy(x: 0, y: -20)
        }, completion: {
            _ in
            // topLabel should be removed exactly here, as bottomLabel's layout
            // depends on topLabel position

            topLabel.removeFromSuperview()
            bottomLabel.removeFromSuperview()
        })
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateProgressView()
    }

    override internal func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    internal override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        _isLoading ? 27 : fileListDataSource?.countOfFiles() ?? 0
    }

    private func nativePreviewImageFor(_ file: FSNode) -> UIImage {
        if file is FSNode.File {
            return getFilePreviewImageByExtension(file.url.pathExtension, inverted: userPreferences.currentTheme.isDark)
        } else {
            if userPreferences.currentTheme.isDark {
                return FilePreviewImages.folderImageInverted
            } else {
                return FilePreviewImages.folderImage
            }
        }
    }

    internal func lightPreviewImageFor(file: FSNode, at index: Int) -> UIImage! {
        previewImageFor(file: file, at: index)
    }

    internal func previewImageFor(file: FSNode, at index: Int) -> UIImage! {
        nil
    }

    func openContextMenu(file: FSNode, actions: [ContextMenuAction], at indexPath: IndexPath, addDeleteButton: Bool = true) {
        let customView = FileQuickInfo()

        let cell = tableView.cellForRow(at: indexPath)!
        let image = lightPreviewImageFor(file: file, at: indexPath.row)

        customView.describeFile(file: file, previewImage: image)

        let alert = UIAlertController(title: nil, customView: customView, fallbackMessage: nil, preferredStyle: .actionSheet)

        for action in actions {
            alert.addAction(UIAlertAction(title: action.title, style: action.style, handler: { (_) in
                action.callback(action)
            }))
        }

        if (addDeleteButton) {

            alert.addAction(UIAlertAction(title: localize("delete"), style: .destructive, handler: { (_) in
                self.deleteFile(at: indexPath.row)
            }))
        }

        alert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: nil))

        alert.popoverPresentationController?.sourceRect = cell.frame
        alert.popoverPresentationController?.sourceView = tableView

        present(alert, animated: true, completion: nil)

        if UIDevice.current.produceSimpleHapticFeedback(level: 1520) {
            if #available(iOS 10.0, *) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
            }
        }
    }

    func fileLongTouched(at index: Int) {
        let file = fileListDataSource.fileList(fileForRowAt: index)
        guard let actions = fileListDataSource.shortcutActionsForFile?(file: file, at: index) else {
            return
        }
        guard !actions.isEmpty else {
            return
        }

        openContextMenu(file: file, actions: actions, at: IndexPath(row: index, section: 0))
    }

    @objc final internal func _fileLongTouched(_ sender: UILongPressGestureRecognizer) {

        if (isSelectingFilesToMove) {
            return
        } else if fileListManager.isRelocatingFiles {
            return
        }

        if
                sender.state == .began,
                let cell = sender.view as? FileListCell,
                let indexPath = tableView.indexPath(for: cell) {

            fileLongTouched(at: indexPath.row)
        }
    }

    private var errorneousFile: FSNode.File! = nil
    private var errorAlert: TCAlertController! = nil

    private func _initPlaceholderAnimationQueue() {

        _loadingAnimationTask = DispatchWorkItem(block: { [weak self] in

            var i: Float = 0

            while let slf = self, slf._isLoading {
                DispatchQueue.main.sync {
                    guard slf.parent != nil else {
                        return
                    }
                    guard let indexPaths = slf.tableView.indexPathsForVisibleRows else {
                        return
                    }

                    for indexPath in indexPaths {
                        let row = Float(indexPath.row)

                        guard let cell = slf.tableView.cellForRow(at: indexPath) as? FileListPlaceholderCell else {
                            return
                        }

                        var index = i - row * 4

                        while index < 0 {
                            index += 100
                        }

                        if index > 100 {
                            i = i - 100
                            index = index - 100
                        }

                        if index >= 20 && index < 40 {
                            let alpha = 1 - CGFloat(index - 20) / 30

                            cell.alpha = alpha
                        } else if index >= 40 && index < 60 {
                            let alpha = CGFloat(index - 40) / 30 + 0.33

                            cell.alpha = alpha
                        } else {
                            cell.alpha = 1.0
                        }
                    }
                }

                i += 2

                Thread.sleep(forTimeInterval: 0.04)
            }
        })
    }


    /// Variable that displays the loading screen when `true` is set.
    /// - note: Call `tableView.reloadData()` after an update
    internal var isLoading: Bool {
        get {
            _isLoading
        }
        set {
            if newValue == _isLoading {
                return
            }

            if newValue {
                _initPlaceholderAnimationQueue()

                fileRefreshControl?.isEnabled = false

                DispatchQueue(label: "easyhtml.filelist.placeholderanimationqueue", qos: .userInteractive).async(execute: _loadingAnimationTask)

                _isLoading = true

                tableView.isUserInteractionEnabled = false
            } else {
                _loadingAnimationTask.cancel()

                fileRefreshControl?.isEnabled = true

                _isLoading = false

                tableView.isUserInteractionEnabled = true
            }
        }
    }

    private var _isLoading = false
    private var _loadingAnimationTask: DispatchWorkItem! = nil

    private func showFileSavingErrorAlert(file: FSNode.File) {
        errorAlert = TCAlertController.getNew()
        errorneousFile = file

        errorAlert.applyDefaultTheme()

        errorAlert.contentViewHeight = 180
        errorAlert.constructView()
        errorAlert.makeCloseableByTapOutside()
        errorAlert.headerText = localize("savingerrorheader")

        let textView = errorAlert.addTextView()

        let sorryText = localize("savingerrordesc")

        let components = sorryText.split(separator: "*")

        let linkVKAttributes: [NSAttributedString.Key: Any] = [
            .strokeColor: UIColor(red: 0.05, green: 0.4, blue: 0.65, alpha: 1.0),
            .link: NSURL(string: "https://vk.com/id208035941")!,
        ]

        let linkMailAttributes: [NSAttributedString.Key: Any] = [
            .strokeColor: UIColor(red: 0.05, green: 0.4, blue: 0.65, alpha: 1.0),
            .link: NSURL(string: "mailto:jakmobius@gmail.com")!,
        ]

        let text = NSMutableAttributedString(string: String(components[0]))
        text.append(NSAttributedString(string: localize("savingerrorvkpage"), attributes: linkVKAttributes))
        text.append(NSAttributedString(string: String(components[1])))
        text.append(NSAttributedString(string: "jakmobius@gmail.com", attributes: linkMailAttributes))
        text.append(NSAttributedString(string: String(components[2])))
        text.addAttributes([.font: UIFont.systemFont(ofSize: 13)], range: NSRange(location: 0, length: text.length))

        textView.attributedText = text
        textView.delegate = self
        textView.textAlignment = .center

        errorAlert.animation = TCAnimation(animations: [TCAnimationType.move(-100, -200), TCAnimationType.rotate(0.4), TCAnimationType.scale(0.4, 1.6)], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.5)

        errorAlert.addAction(action: TCAlertAction(text: "ОК", action: {
            _, _ in
            file.setSavingState(state: .saved)
            FileBrowser.fileMetadataChanged(file: file)
            self.errorneousFile = nil
            self.errorAlert = nil
        }, shouldCloseAlert: true))

        view.window!.addSubview(errorAlert.view)
    }

    internal override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isSelectingFilesToMove && tableView.indexPathsForSelectedRows?.isEmpty ?? true {
            navigationItem.rightBarButtonItem!.isEnabled = false
        }
    }

    internal override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if (isSelectingFilesToMove) {

            // Find and remove bugged separatorView.
            // TODO: dirty

            if let cell = tableView.cellForRow(at: indexPath) {
                for view in cell.subviews {
                    if view.frame.height < 2 && view.frame.maxY < cell.frame.height - 5 {
                        view.removeFromSuperview()
                        break
                    }
                }
            }

            navigationItem.rightBarButtonItem!.isEnabled = true

            return
        }

        tableView.deselectRow(at: indexPath, animated: true)

        let file = fileListDataSource.fileList(fileForRowAt: indexPath.row)
        if let file = file as? FSNode.File {
            let savingState = file.getSavingState()

            if case .error(let backup) = savingState {
                if let backup = backup {
                    backup.tryToRestore()
                } else {
                    showFileSavingErrorAlert(file: file)
                }

                return
            } else if case .saving = savingState {
                return

            }
        }

        if (indexPath.section == 0) {

            fileListDelegate?.fileList?(selectedFileAt: indexPath.row)
        }
    }

    internal func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        if errorAlert != nil && (
                URL.absoluteString == "https://vk.com/id208035941" ||
                        URL.absoluteString == "mailto:jakmobius@gmail.com"
        ) {
            errorAlert?.dismissWithAnimation()
            errorneousFile?.setSavingState(state: .saved)
            FileBrowser.fileMetadataChanged(file: errorneousFile)
            errorneousFile = nil
            errorAlert = nil
        }
        return true
    }

    @objc internal func fileForceTouched(_ sender: ForceTouchGestureRecognizer) {
        if (fileListManager.isRelocatingFiles) {
            return
        }
        if (sender.state == .cancelled || presentedViewController != nil) {
            return
        }

        if (sender.force.isNaN) {
            return
        }

        let view = sender.view!

        guard let cell = view as? UITableViewCell else {
            return
        }
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        if !(fileListDataSource?.shouldRecognizeForceTouchFor?(fileAt: indexPath.row) ?? false) {
            if (sender.view!.transform != .identity) {
                UIView.animate(withDuration: 0.5, animations: {
                    sender.view?.transform = .identity
                })
            }
            sender.cancel()
            return
        }

        let scale = min(max(0.95 + sender.force / 10, 1), 1.2)

        sender.view!.transform = CGAffineTransform(scaleX: scale, y: scale)

        if (sender.force >= 1) {
            sender.cancel()

            let tag = indexPath.row

            if UIDevice.current.produceSimpleHapticFeedback(level: 1520) {
                if #available(iOS 10.0, *) {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                }
            }

            UIView.animate(withDuration: 0.3, animations: {
                sender.view!.transform = .identity
            }, completion: {
                _ in
                let indexPath = IndexPath(row: tag, section: 0)
                self.tableView.reloadRows(at: [indexPath], with: .none)
            })
        }
    }

    internal override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if _isLoading {
            let cell = tableView.dequeueReusableCell(withIdentifier: "placeholdercell", for: indexPath) as! FileListPlaceholderCell
            cell.backgroundColor = indexPath.row % 2 == 1 ?
                    userPreferences.currentTheme.cellColor1 :
                    userPreferences.currentTheme.cellColor2
            cell.beginAnimationWithDelay(delay: Double(indexPath.row) * 0.04 + 0.1)
            return cell
        }

        if (fileListDataSource == nil) {
            fatalError("fileListDataSource is nil. I have no idea what you've done to get there.");
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! FileListCell

        for recognizer in cell.gestureRecognizers ?? [] {
            cell.removeGestureRecognizer(recognizer)
        }

        let file = fileListDataSource.fileList(fileForRowAt: indexPath.row)

        let isMoving =
                isMovingSourceFolder &&
                        fileListManager.filesRelocationManager != nil &&
                        fileListManager.filesRelocationManager!.filesToMove.contains(file)

        if let folder = file as? FSNode.Folder {

            let countOfFilesInside = folder.countOfFilesInside
            if (countOfFilesInside == -1) {
                cell.detailLabel.text = localize("folder")
            } else if (countOfFilesInside == 0) {
                cell.detailLabel.text = localize("emptyfolder", .files)
            } else {
                cell.detailLabel.text = "\(localize("objects")): \(countOfFilesInside)"
            }

            cell.detailLabel.textColor = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
        } else if let file = file as? FSNode.File {

            let savingState = file.getSavingState()
            switch savingState {
            case .error(let backup):
                if backup == nil {
                    cell.detailLabel.text = localize("savingerror")
                } else {
                    cell.detailLabel.text = localize("savingerrortryagain")
                }
                cell.detailLabel.textColor = #colorLiteral(red: 1, green: 0, blue: 0, alpha: 1)
                break;
            case .saving:
                cell.detailLabel.text = localize("saving")
                cell.detailLabel.textColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
                break;
            case .saved:
                cell.detailLabel.text = getLocalizedFileSize(bytes: file.size)
                cell.detailLabel.textColor = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
            }
        } else if file is FSNode.Shortcut {
            cell.detailLabel.text = localize("symlink")
        }

        if isMoving || file.name.hasPrefix(".") {
            cell.contentView.alpha = 0.3
        } else {
            cell.contentView.alpha = 1.0
        }

        cell.tintColor = userPreferences.currentTheme.detailDisclosureButtonColor

        if isMoving || isSelectingFilesToMove {
            cell.accessoryType = .none
        } else if fileListManager.isRelocatingFiles {
            if file is FSNode.File {
                cell.accessoryType = .none
            } else {
                cell.accessoryType = .disclosureIndicator
            }
        } else {
            cell.accessoryType = .detailDisclosureButton
        }

        cell.backgroundColor = indexPath.row % 2 == 1 ?
                userPreferences.currentTheme.cellColor1 :
                userPreferences.currentTheme.cellColor2

        cell.title.text = file.name
        cell.title.textColor = userPreferences.currentTheme.cellTextColor

        cell.cellImage.image = previewImageFor(file: file, at: indexPath.row) ?? nativePreviewImageFor(file)

        let gestureRecogniser = UILongPressGestureRecognizer(target: self, action: #selector(_fileLongTouched(_:)))
        gestureRecogniser.minimumPressDuration = 0.4
        cell.addGestureRecognizer(gestureRecogniser)

        if (fileListDataSource.shouldRecognizeForceTouchFor?(fileAt: indexPath.row) ?? false) {
            let forceTouchGestureRecognizer = ForceTouchGestureRecognizer(target: self, action: #selector(fileForceTouched(_:)))
            forceTouchGestureRecognizer.delegate = self
            cell.addGestureRecognizer(forceTouchGestureRecognizer)
        }

        return cell
    }

    internal func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is ForceTouchGestureRecognizer {
            return false
        }
        return true
    }

    internal override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        50
    }

    internal override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        50
    }

    func showFileSizeWarning(callback: @escaping () -> ()) {
        let alert = TCAlertController.getNew()

        alert.buttonColor = UIColor.white
        alert.buttonHighlightedColor = UIColor(white: 0.9, alpha: 1.0)
        alert.buttonImage = UIImage.getImageFilledWithColor(color: userPreferences.currentTheme.themeColor)
        alert.buttonHighlightedImage = UIImage.getImageFilledWithColor(color: userPreferences.currentTheme.cellSelectedColor)

        alert.contentViewHeight = 150
        alert.constructView()
        alert.headerText = localize("fileisverybig")
        alert.makeCloseableByTapOutside()

        let label = UILabel(frame: CGRect(x: 10, y: 0, width: 230, height: 150))
        label.text = localize("fileisverybigmessage")
        label.textColor = UIColor.gray
        label.font = UIFont.systemFont(ofSize: 13)
        label.numberOfLines = 14
        label.textAlignment = .center

        alert.contentView.addSubview(label)

        alert.animation = TCAnimation(animations: [TCAnimationType.scale(0.3, 0.3)], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.3)

        alert.addAction(action: TCAlertAction(text: localize("yes"), action: { _, _ in callback() }, shouldCloseAlert: true))
        alert.addAction(action: TCAlertAction(text: localize("no"), shouldCloseAlert: true))

        PrimarySplitViewController.instance(for: view).present(alert, animated: false)
    }

    func openSourceCode(file: FSNode.File, config: EditorConfiguration? = nil) {

        func open() {
            let switcherView = PreviewContainer.activeSwitcherView(for: view.window)
            let editor = Editor.getEditor(configuration: config, file: file, in: switcherView)

            if editor.focusIf(fileIs: file, controllerIs: WebEditorController.self, animated: true) {
                editor.openFile(file: file, using: GeneralSourceCodeEditor.forExt(file.url.pathExtension), with: config, in: switcherView)
            }
        }

        if file.size <= 512000 {
            open()
        } else {
            showFileSizeWarning(callback: open)
        }
    }

    func openAsImage(file: FSNode.File, config: EditorConfiguration? = nil) {

        let switcherView = PreviewContainer.activeSwitcherView(for: view.window)
        let editor = Editor.getEditor(configuration: config, file: file, in: switcherView)

        if editor.focusIf(fileIs: file, controllerIs: ImagePreviewController.self, animated: true) {
            editor.openFile(file: file, using: ImagePreviewController(), with: config, in: switcherView)
        }

    }

    func openInBrowser(file: FSNode.File, config: EditorConfiguration? = nil, force: Bool = false) {

        let switcherView = PreviewContainer.activeSwitcherView(for: view.window)
        let editor = Editor.getEditor(configuration: config, file: file, in: switcherView)

        func openWithCache() {
            if editor.focusIf(fileIs: file, controllerIs: CacheNeededFilePreviewController.self) {
                editor.openFile(file: file, using: CacheNeededFilePreviewController(), with: config, in: switcherView)
            }
        }

        func openWithoutCache() {
            if editor.focusIf(fileIs: file, controllerIs: AnotherFilePreviewController.self) {
                editor.openFile(file: file, using: AnotherFilePreviewController(), with: config, in: switcherView)
            }
        }

        let e = file.url.pathExtension.lowercased()

        if Editor.cacheNeededExtensions.contains(e) {
            openWithCache()
        } else if force || Editor.notCacheNeededExtensions.contains(e) {
            openWithoutCache()
        } else {
            UnknownExtensionAlert.present(on: view.window!, file: file) { type in
                switch type {
                case .sourceCodeEditor:
                    self.openSourceCode(file: file)
                case .webBrowser:
                    openWithoutCache()
                }
            }
        }

        //showDetailViewController(navigationController, sender: nil)
    }

    internal override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        localize("delete")
    }

    private var doesSelect = false

    internal override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {

        if !canEditRow(at: indexPath) {
            return .none
        }

        return isSelectingFilesToMove ? UITableViewCell.EditingStyle(rawValue: 3)! : .delete
    }

    func canEditRow(at indexPath: IndexPath) -> Bool {
        if isSelectingFilesToMove {
            return fileListDataSource!.canMoveFile?(at: indexPath.row) ?? true
        } else if isMovingSourceFolder && fileListManager.filesRelocationManager != nil {
            let file = fileListDataSource!.fileList(fileForRowAt: indexPath.row)
            return !fileListManager!.filesRelocationManager.filesToMove.contains(file)
        } else {
            return fileListDataSource!.canDeleteFile?(at: indexPath.row) ?? true
        }
    }

    internal override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        canEditRow(at: indexPath)
    }

    internal func deleteFile(at index: Int) {
        deleteFile(at: index, file: fileListDataSource!.fileList(fileForRowAt: index))
    }

    internal func deleteFile(at index: Int, file: FSNode) {

        func delete(action: UIAlertAction) {
            TemporaryFileMetadataManager.clearMetadata(forFile: file)

            fileListDelegate?.fileList?(deleted: file)

        }

        let title = localize(/*# -tcanalyzerignore #*/ file is FSNode.File ? "filedeletealert" : "folderdeletealert")

        let deleteAlert = UIAlertController(title: title, message: localize("cannotbeundone"), preferredStyle: .actionSheet)
        deleteAlert.addAction(UIAlertAction(title: localize("delete"), style: .destructive, handler: delete))
        deleteAlert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler: {
            _ in
            self.tableView.endEditing(true)
        }))

        let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0))

        deleteAlert.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: cell!.bounds.origin.x + cell!.bounds.width, y: cell!.bounds.origin.y + 20), size: CGSize(width: 50, height: 30))
        deleteAlert.popoverPresentationController?.sourceView = cell?.contentView

        present(deleteAlert, animated: true, completion: nil)
    }

    override internal func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
            deleteFile(at: indexPath.row)
        }
    }

    // MARK: File relocation management

    internal func updateNavigationItemButtons() {

    }

    private(set) var isSelectingFilesToMove = false

    @objc func endEditing() {
        isSelectingFilesToMove = false
        isMovingSourceFolder = false

        if let indexPaths = tableView.indexPathsForSelectedRows {
            for indexPath in indexPaths {
                tableView.deselectRow(at: indexPath, animated: false)
            }
        }
        tableView.setEditing(false, animated: true)

        updateNavigationItemButtons()

        if let manager = fileListManager.filesRelocationManager {
            manager.stopRelocatingFiles()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let rows = self.tableView.indexPathsForVisibleRows {
                    self.tableView.reloadRows(at: rows, with: .fade)
                }
            }

        }

        tableView.contentInset.bottom = 30
    }

    internal func stopMovingFiles() {
        isMovingSourceFolder = false
        tableView.contentInset.bottom = 30

        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Override the superclass implementation
    }

    internal override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {

        if _isLoading {
            return nil
        }

        if isSelectingFilesToMove {
            if fileListDataSource!.canMoveFile?(at: indexPath.row) ?? true {
                return indexPath
            } else {
                return nil
            }
        } else if isMovingSourceFolder && fileListManager.filesRelocationManager!.filesToMove.contains(fileListDataSource.fileList(fileForRowAt: indexPath.row)) {
            return nil
        }

        return indexPath
    }

    @objc func relocateSelectedFiles() {

        updateNavigationItemButtons()
        isSelectingFilesToMove = false

        if let indexPaths = tableView.indexPathsForSelectedRows {
            var cells: [UITableViewCell] = []
            var files: [FSNode] = []

            for indexPath in indexPaths {
                if let cell = tableView.cellForRow(at: indexPath) {
                    cells.append(cell)
                    cell.contentView.alpha = 0.3
                    cell.accessoryType = .none
                }

                tableView.deselectRow(at: indexPath, animated: true)

                let file = fileListDataSource.fileList(fileForRowAt: indexPath.row)
                files.append(file)
            }
            isMovingSourceFolder = true
            fileListManager.startMovingFiles(cells: cells, files: files)
            tableView.contentInset.bottom = fileMovingDialogHeight
        }

        tableView.setEditing(false, animated: true)
    }

    private var fileMovingDialogHeight: CGFloat = 150

    internal func selectFileToRelocate(at indexPath: IndexPath) {
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }

        isSelectingFilesToMove = true
        tableView.setEditing(true, animated: true)

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(endEditing))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: localize("next"), style: .done, target: self, action: #selector(relocateSelectedFiles))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let rows = self.tableView.indexPathsForVisibleRows {
                self.tableView.reloadRows(at: rows, with: .fade)
            }
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            self.tableView(self.tableView, didSelectRowAt: indexPath)
        }
    }

    // MARK: File relocation management

    internal var canReceiveFiles: Bool {
        true
    }

    func canReceiveFile(file: FSNode, from source: FileSourceType) -> FilesRelocationManager.FileReceiveAbility {
        .yes
    }

    func receiveFile(file: String, from source: FileSourceType, storedAt atURL: URL, callback: @escaping FilesRelocationCompletion, progress: @escaping (Float) -> ()) {

    }

    internal func prepareToRelocation(file: FSNode, to destination: FileSourceType, completion: @escaping (URL?, Error?) -> (), progress: @escaping (Float) -> ()) {

    }

    internal var sourceType: FileSourceType {
        .local
    }

    internal func hasRetainedFile(file: FSNode) {
        if let visiblePaths = tableView.indexPathsForVisibleRows {
            tableView.reloadRows(at: visiblePaths, with: .none)
        }

    }

    private var preferredTitle: String?
    override var title: String? {
        get {
            preferredTitle
        }
        set {
            preferredTitle = newValue
            if url == nil {
                super.title = preferredTitle
            } else {
                updateFilesRelocationState(task: FilesRelocationTask.getFor(controller: self))
            }
        }
    }

    private var progressView: UIProgressView!

    private func updateProgressView() {
        guard progressView != nil else {
            return
        }


        progressView.frame = CGRect(x: 0, y: tableView.contentOffset.y + tableView.layoutMargins.top, width: tableView.bounds.width, height: 3)
    }

    private func createProgressView() {
        progressView = UIProgressView()

        tableView.addSubview(progressView)

        updateProgressView()
    }

    internal func updateFilesRelocationState(task: FilesRelocationTask) {
        if task.of == 0 {
            if (progressView != nil) {
                progressView.setProgress(1.0, animated: true)
                let progressView = progressView!
                self.progressView = nil
                UIView.animate(withDuration: 0.3, animations: {
                    progressView.alpha = 0
                }, completion: {
                    _ in
                    progressView.removeFromSuperview()
                })

            }
            super.title = preferredTitle
        } else {
            if (progressView == nil) {
                createProgressView()
            }

            progressView.setProgress(task.fractionCompleted, animated: true)

            super.title = localize("copyingfiles", .files)
                    .replacingOccurrences(of: "#1", with: String(task.copied))
                    .replacingOccurrences(of: "#2", with: String(task.of))
        }
    }

    deinit {
        clearNotificationHandling()
    }
}
