//
//  Editor.swift
//  EasyHTML
//
//  Created by Артем on 23.04.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

internal typealias FileEditorController = UIViewController & FileEditor

internal class Editor : NSObject, EditorTabViewDelegate
{
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
    
    /**
        Менеджер ввода / вывода для редактора
     */
    
    internal class IOManager {
        
        internal typealias ReadResult = ((Data?, Error?) -> ())?
        internal typealias WriteResult = ((Error?) -> ())?
        
        private final var requests = [CancellableRequest]()
        
        /**
            Завершить все действующие запросы
         */
        
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
            
            //print("request completed")
            
            //Thread.callStackSymbols.forEach{print($0)}
            
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
         Асинхронная отправка запроса загрузки файла на локальную или удаленную файловую систему.
         
         - parameter url: URL файла, который необходимо скачать
         - parameter completion: Блок, вызывающийся по завершению операции.
         - parameter progress: Вызывается периодически, аргумент хранит прогресс скачивания
         
         - returns: Объект отменяемого запроса. Если в процессе загрузки пользователь закрыл окно редактора, чтение файла можно отменить
         */
        
        @discardableResult internal func readFileAt(url: URL, completion: ReadResult, progress: ((Progress) -> ())? = nil) -> CancellableRequest! {
            //print("reading file")
            
            var url = URL(fileURLWithPath: url.path)
            
            var request: CancellableRequest!
            var workItem: DispatchWorkItem!
            
            workItem = DispatchWorkItem(qos: .userInitiated) {
                //print("workitem started")
                func completeRequest(data: Data?, error: Error?) {
                    DispatchQueue.main.async {
                        if self.requestCompleted(request) {
                            completion?(data, error)
                            //if(completion == nil) {
                            //    print("completion is nil, wtf?")
                            //}
                        } else {
                            //print("request completed twice")
                        }
                    }
                }
                
                do {
                    
                    let data = try Data(contentsOf: url, options: [])
                    //print("fetched data")
                    completeRequest(data: data, error: nil)
                } catch {
                    completeRequest(data: nil, error: error)
                }
            }
            
            request = CancellableRequest {
                [weak workItem] request in
                //print("CANCELLING REQUEST!!")
                self.requestCompleted(request)
                workItem?.cancel()
            }
            
            DispatchQueue(label: "easyhtml.iomanager.readingtask").async(execute: workItem)
            
            requestStarted(request)
            
            return request
        }
        
        /**
         Асинхронная отправка запроса сохранения файла на локальную или удаленную файловую систему. Операция неотменяемая
         
         - parameter url: URL файла, который необходимо сохранить
         - parameter completion: Блок, вызывающийся по завершению операции.
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
        self.tabView.navController.editorViewController = self.controller!
        self.tabView.navController.presentView()
        
        if(animated) {
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
        
        if(!animated) {
            UIView.setAnimationsEnabled(true)
        }
    }
    
    final func didBlur() {
        if let controller = self.controller, controller.canHandleMessage(message: .blur) {
            controller.handleMessage(message: .blur, userInfo: nil)
        }
    }
    
    static var focusedByShortcutKey = "focused_by_shortcut"
    
    final func didFocus(byShortcut: Bool = false) {
        if let controller = self.controller, controller.canHandleMessage(message: .focus) {
            let userInfo = [
                Editor.focusedByShortcutKey: byShortcut
            ]
            controller.handleMessage(message: .focus, userInfo: userInfo)
        }
    }
    
    /**
        Закрывает редактор. Удаляет его из списка открытых редакторов. Отправляет редактору сообщение о закрытии.
     */
    
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
        
        if  controller != nil &&
            file == self.file &&
            editor.identifier == type(of: controller!).identifier {
            self.focus(animated: animated)
            return false
        }
        
        return true
    }
    
    final func focus(animated: Bool, in switcherView: EditorSwitcherView! = nil) {
        
        if tabView == nil {
            present(animated: animated, in: switcherView!)
            return
        }
        
        var switcherView = tabView.parentView!
        
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
                            self.tabView.parentView.locked = false
                            self.tabView.parentView.animateIn(animated: animated, view: self.tabView)
                        }
                        
                        if animated {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                complete()
                            }
                        } else {
                            complete()
                        }
                    } else {
                        self.tabView.parentView.animateIn(animated: animated, view: self.tabView)
                        AppDelegate.updateSceneTitle(for: self.tabView.parentView.window!)
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
     Открывает файл в редакторе
     
     - parameter file: Файл, который необходимо открыть
     - parameter using: Контроллер редактора
     - parameter config: Конфигурация редактора
     - parameter animated: Флаг, обозначающий стоит ли анимировать открытие файла
     */
    
    internal func openFile(file: FSNode.File!, using editor: FileEditorController, with config: EditorConfiguration? = nil, animated: Bool = true, in switcherView: EditorSwitcherView! = nil) {
        
        if tabView?.parentView?.locked == true {
            return
        }
            
        var config = config
        
        // Сохраняем файл, который уже открыт в этой вкладке
        
        save()
        if controller?.canHandleMessage(message: .close) == true {
            controller!.handleMessage(message: .close, userInfo: nil)
        }
        
        // Как говорится, It's now safe to turn off your editor.
        // Удаляем старый контроллер и заменяем новым.
        
        controller = editor
        
        self.file = file
        
        if config == nil {
            config = [:]
        }
        
        config![.editor] = self
        
        editor.applyConfiguration(config: config!)
        
        focus(animated: animated, in: switcherView)
        
        guard tabView != nil else { return }
        
        tabView.navController.editorViewController = controller!
        tabView.navController.presentView()
        
        tabView.isRemovable = true
        
        let window = switcherView.window
        
        AppDelegate.updateSceneTitle(for: window!)
        
        userPreferences.statistics.filesOpened += 1
    }
    
    /**
        Текущий редактируемый файл
     */
    
    internal var file: FSNode.File?
    
    /**
        Текущий контроллер редактора
     */
    
    internal var controller: FileEditorController?
    
    /**
        Закрывает редактор, не сохраняя файл.
     */
    
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
                if tabView.index >= 1 && tabView.index <= 4  {
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
            guard let editorfile = editor.file else { continue }
            
            if file is FSNode.File ? editorfile == file : editorfile.url.path.hasPrefix(file.url.path) {
                editor.closeTab()
            }
        }
    }
    
    internal static func fileMoved(file: FSNode, to destinationURL: URL) {
        
        let destinationPathComponents = destinationURL.pathComponents
        
        for editor in Editor.openedEditors {
        
            guard let controller = editor.controller else { continue }
            guard controller.canHandleMessage(message: .fileMoved) else { continue }
            guard let editorfile = editor.file else { continue }
            guard editorfile.sourceType == file.sourceType else { continue }
            
            if file is FSNode.Folder {
                if editorfile.url.path.hasPrefix(file.url.path) {
                    var filePathComponents = editorfile.url.pathComponents
                    let oldComponents = file.url.pathComponents
                    
                    filePathComponents.removeSubrange(0 ..< oldComponents.count)
                    filePathComponents.insert(contentsOf: destinationPathComponents, at: 0)
                    
                    if(filePathComponents.first == "/") {
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
            guard editor.controller?.canHandleMessage(message: message) == true else { continue }
            
            editor.controller!.handleMessage(message: message, userInfo: userInfo)
        }
    }
}
