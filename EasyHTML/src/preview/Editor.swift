//
//  Editor.swift
//  EasyHTML
//
//  Created by Артем on 23.04.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

internal typealias FileEditorController = UIViewController & FileEditor

internal class Editor: NSObject, EditorTabViewDelegate {
    static var openedEditors: [Editor] = []

    static func getEditor(configuration: EditorConfiguration!, file: FSNode.File, in switcherView: EditorSwitcherView) -> Editor {

        for editor in Editor.openedEditors {
            if editor.file == file && editor.tabView.parentView == switcherView {
                return editor
            }
        }

        if let newTab = configuration?[.openInNewTab] as? Bool, newTab {
            return Editor()
        } else if let presentedTabView = switcherView.presentedView {

            let hasPrimaryTab = switcherView.hasPrimaryTab

            var vacantIndex: Int

            if hasPrimaryTab && presentedTabView.index == 0 {
                vacantIndex = switcherView.lastOpenedView?.index ?? 0
            } else {
                vacantIndex = presentedTabView.index
            }

            for editor in Editor.openedEditors {

                if hasPrimaryTab && editor.tabView.index == 0 {
                    continue
                }

                if editor.tabView.parentView != switcherView {
                    continue
                }

                if editor.tabView.index == vacantIndex {
                    return editor
                }
            }
        }
        return Editor()
    }

    static var imageExtensions = ["jpg", "jpeg", "bmp", "png", "gif", "ico", "heic"]

    static func syntaxHighlightingSchemeFor(ext: String) -> SyntaxHighlightScheme? {

        let ext = ext.lowercased()

        for type in userPreferences.syntaxHighlightingConfiguration where type.ext == ext {
            return type
        }

        return nil
    }

    static var cacheNeededExtensions = ["doc", "dot", "docx", "dotx", "docm", "dotm", "xls", "xlt", "xla", "xlsx", "xltx", "xlsm", "xltm", "xlam", "xlsb", "ppt", "pot", "pps", "ppa", "pptx", "potx", "ppsx", "ppam", "pptm", "potm", "ppsm", "rtf", "key", "numbers", "pdf", "mp3", "mp4", "m4a"]
    static var notCacheNeededExtensions = ["html", "htm"]

    internal class IOManager {

        internal typealias ReadResult = ((Data?, Error?) -> ())?
        internal typealias WriteResult = ((Error?) -> ())?

        private final var requests = [CancellableRequest]()

        /// Cancel all ongoing requests
        final func stopActivity() {
            for request in requests {
                request.cancel()
            }

            requests = []
        }

        @discardableResult final func requestCompleted(_ request: CancellableRequest!) -> Bool {
            if request == nil {
                return false
            }

            if let index = requests.firstIndex(of: request) {
                requests.remove(at: index)
                return true
            }

            return false
        }

        final func requestStarted(_ request: CancellableRequest!) {
            if request == nil {
                return
            }
            requests.append(request)
        }


        /**
         Asynchronously send a file download request to a local or remote file system.
         
         - parameter url: URL of the file you want to download
         - parameter completion: Completion callback
         - parameter progress: Progress callback
         
         - returns: A `CancellableRequest` instance. If editor window is closed before
            download is complete, it can be interrupted.
         */

        @discardableResult internal func readFileAt(url: URL, completion: ReadResult, progress: ((Progress) -> ())? = nil) -> CancellableRequest! {

            let url = URL(fileURLWithPath: url.path)

            var request: CancellableRequest!
            var workItem: DispatchWorkItem!

            workItem = DispatchWorkItem(qos: .userInitiated) {
                func completeRequest(data: Data?, error: Error?) {
                    DispatchQueue.main.async {
                        if self.requestCompleted(request) {
                            completion?(data, error)
                        }
                    }
                }

                do {
                    let data = try Data(contentsOf: url, options: [])
                    completeRequest(data: data, error: nil)
                } catch {
                    completeRequest(data: nil, error: error)
                }
            }

            request = CancellableRequest {
                [weak workItem] request in
                self.requestCompleted(request)
                workItem?.cancel()
            }

            DispatchQueue(label: "easyhtml.iomanager.readingtask").async(execute: workItem)

            requestStarted(request)

            return request
        }

        /**
         Asynchronously sends a file saving request to a local or remote file system. The operation is irrevocable
         
         - parameter url: URL of the file to be saved
         - parameter completion: Completion callback
         */

        internal func saveFileAt(url: URL, data: Data, completion: WriteResult = nil) {

            DispatchQueue(label: "easyhtml.iomanager.writingtask").async {
                do {
                    try data.write(to: url)
                    DispatchQueue.main.async {
                        completion?(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion?(error)
                    }
                }
            }
        }
    }

    internal enum ConfigKey: String {
        case
                ioManager = "ioManager",
                isReadonly = "isReadonly",
                textEncoding = "textEncoding",
                editor = "editor",
                openInNewTab = "newtab"
    }

    var tabView: EditorTabView! = nil

    internal func present(animated: Bool = true, in editorSwitcherView: EditorSwitcherView) {
        guard tabView == nil else {
            return
        }

        Editor.openedEditors.append(self)

        let nc = PreviewNavigationController()

        let editorTabView = EditorTabView(frame: editorSwitcherView.frame, navigationController: nc)
        tabView = editorTabView
        tabView.delegate = self

        UIView.setAnimationsEnabled(false)
        tabView.navController.editorViewController = controller!
        tabView.navController.presentView()

        if (animated) {
            UIView.setAnimationsEnabled(true)
        }

        if editorSwitcherView.hasPrimaryTab && editorSwitcherView.containerViews.count == 1 {
            editorSwitcherView.addContainerViewsSilently([editorTabView])
            editorSwitcherView.animateBottomViewIn()
        } else {
            editorSwitcherView.addContainerView(editorTabView, animated: animated) {
                editorSwitcherView.animateIn(animated: animated, view: editorTabView)
                editorTabView.layoutSubviews()
            }
        }

        if (!animated) {
            UIView.setAnimationsEnabled(true)
        }
    }

    final func didBlur() {
        if let controller = controller, controller.canHandleMessage(message: .blur) {
            controller.handleMessage(message: .blur, userInfo: nil)
        }
    }

    static var focusedByShortcutKey = "focused_by_shortcut"

    final func didFocus(byShortcut: Bool = false) {
        if let controller = controller, controller.canHandleMessage(message: .focus) {
            let userInfo = [
                Editor.focusedByShortcutKey: byShortcut
            ]
            controller.handleMessage(message: .focus, userInfo: userInfo)
        }
    }

    /// Closes the editor. Deletes it from the list of open editors. Sends a closing message to the editor.
    func closeEditor() {
        if controller?.canHandleMessage(message: .close) == true {
            controller!.handleMessage(message: .close, userInfo: nil)
        }

        if let index = Editor.openedEditors.firstIndex(where: { $0 == self }) {
            Editor.openedEditors.remove(at: index)
        }

        tabView = nil
        file = nil
        controller = nil
    }

    final func tabWillClose(editorTabView: EditorTabView) {
        save()
        closeEditor()
    }

    final func focusIf(fileIs file: FSNode, controllerIs editor: FileEditorController.Type, animated: Bool = true) -> Bool {

        if controller != nil &&
                   file == self.file &&
                   editor.identifier == type(of: controller!).identifier {
            focus(animated: animated)
            return false
        }

        return true
    }

    final func focus(animated: Bool, in switcherView: EditorSwitcherView! = nil) {

        if tabView == nil {
            present(animated: animated, in: switcherView!)
            return
        }

        let switcherView = tabView.parentView!

        let presentedView = switcherView.presentedView

        let mustAnimateToAnotherEditor = presentedView != tabView
        let canUseBottomViewAnimation =
                switcherView.hasPrimaryTab &&
                        switcherView.containerViews.count == 2 &&
                        switcherView.presentedView.index == 0

        if canUseBottomViewAnimation {
            switcherView.animateBottomViewIn()
        } else if mustAnimateToAnotherEditor {

            func presentSelf() {

                let scrollView = tabView!.parentView.scrollView!
                let rect = tabView!.convert(tabView!.bounds, to: scrollView)

                if tabView.parentView.isCompact {
                    tabView.parentView.locked = true

                    scrollView.scrollRectToCenter(rect, animated: animated, completion: {
                        self.tabView.parentView.locked = false
                        self.tabView.parentView.animateIn(animated: animated, view: self.tabView)
                    })
                } else {

                    if rect.maxY >= scrollView.bounds.height + scrollView.contentOffset.y ||
                               rect.minY <= scrollView.contentOffset.y {
                        tabView.parentView.locked = true

                        scrollView.scrollRectToVisible(rect, animated: animated)

                        func complete() {
                            tabView.parentView.locked = false
                            tabView.parentView.animateIn(animated: animated, view: tabView)
                        }

                        if animated {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                complete()
                            }
                        } else {
                            complete()
                        }
                    } else {
                        tabView.parentView.animateIn(animated: animated, view: tabView)
                        AppDelegate.updateSceneTitle(for: tabView.parentView.window!)
                    }
                }
            }

            if tabView.parentView.isFullScreen {
                tabView!.parentView.animateOut(animated: animated, force: false, completion: presentSelf)
            } else {
                presentSelf()
            }
        } else {
            if controller != nil, controller!.canHandleMessage(message: .focus) {
                controller!.handleMessage(message: .focus, userInfo: nil)
            }
        }
    }

    /**
     Opens file in this editor
     
     - parameter file: File to open
     - parameter using: Editor controller
     - parameter config: Editor configuration
     - parameter animated: Flag indicating whether to animate the opening of a file
     */

    internal func openFile(file: FSNode.File!, using editor: FileEditorController, with config: EditorConfiguration? = nil, animated: Bool = true, in switcherView: EditorSwitcherView! = nil) {

        if tabView?.parentView?.locked == true {
            return
        }

        var config = config

        // Save file that was already opened in this tab

        save()
        if controller?.canHandleMessage(message: .close) == true {
            controller!.handleMessage(message: .close, userInfo: nil)
        }

        // Delete old controller and create a new one

        controller = editor

        self.file = file

        if config == nil {
            config = [:]
        }

        config![.editor] = self

        editor.applyConfiguration(config: config!)

        focus(animated: animated, in: switcherView)

        guard tabView != nil else {
            return
        }

        tabView.navController.editorViewController = controller!
        tabView.navController.presentView()

        tabView.isRemovable = true

        let window = switcherView.window

        AppDelegate.updateSceneTitle(for: window!)

        userPreferences.statistics.filesOpened += 1
    }

    /// File that is being edited
    internal var file: FSNode.File?

    /// Current editor controller
    internal var controller: FileEditorController?

    /// Closes the editor without saving the file
    internal func closeTab() {
        guard let tabView = tabView, let switcher = tabView.parentView else {
            return
        }

        self.tabView = nil

        closeEditor()

        if switcher.presentedView == tabView {
            switcher.animateOut(animated: true, force: false) {
                tabView.closeTab()
            }
        } else {

            var shouldAnimateRemoval = false

            if switcher.hasPrimaryTab && switcher.presentedView.index == 0 {
                if tabView.index >= 1 && tabView.index <= 4 {
                    shouldAnimateRemoval = true
                }
            }

            tabView.closeTab(animated: shouldAnimateRemoval, completion: nil)

            tabView.parentView.layoutSubviews()
        }
    }

    func save() {
        if controller?.canHandleMessage(message: .save) == true {
            controller!.handleMessage(message: .save, userInfo: nil)
        }
    }

    internal static func fileDeleted(file: FSNode) {

        for editor in Editor.openedEditors {
            guard let editorfile = editor.file else {
                continue
            }

            if file is FSNode.File ? editorfile == file : editorfile.url.path.hasPrefix(file.url.path) {
                editor.closeTab()
            }
        }
    }

    internal static func fileMoved(file: FSNode, to destinationURL: URL) {

        let destinationPathComponents = destinationURL.pathComponents

        for editor in Editor.openedEditors {

            guard let controller = editor.controller else {
                continue
            }
            guard controller.canHandleMessage(message: .fileMoved) else {
                continue
            }
            guard let editorfile = editor.file else {
                continue
            }
            guard editorfile.sourceType == file.sourceType else {
                continue
            }

            if file is FSNode.Folder {
                if editorfile.url.path.hasPrefix(file.url.path) {
                    var filePathComponents = editorfile.url.pathComponents
                    let oldComponents = file.url.pathComponents

                    filePathComponents.removeSubrange(0..<oldComponents.count)
                    filePathComponents.insert(contentsOf: destinationPathComponents, at: 0)

                    if (filePathComponents.first == "/") {
                        filePathComponents.removeFirst()
                    }

                    let newFileURL = URL(fileURLWithPath: filePathComponents.joined(separator: "/"))

                    controller.handleMessage(message: .fileMoved, userInfo: newFileURL)
                    controller.editor.tabView.navController.updateTitle()
                }
            } else if file.url == editorfile.url {
                controller.handleMessage(message: .fileMoved, userInfo: destinationURL)
                controller.editor.tabView.navController.updateTitle()
            }
        }
    }

    internal static func sendMessageToAllEditors(message: EditorMessage, userInfo: Any?) {
        for editor in Editor.openedEditors {
            guard editor.controller?.canHandleMessage(message: message) == true else {
                continue
            }

            editor.controller!.handleMessage(message: message, userInfo: userInfo)
        }
    }
}
