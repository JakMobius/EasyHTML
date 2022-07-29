//
//  SourceCodeEditorSessionDispatcher.swift
//  EasyHTML
//
//  Created by Артем on 07.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

class SourceCodeEditorSessionDispatcher: EditorDelegate {
    weak var session: SourceCodeEditorSession? {
        didSet {
            file = session?.file
        }
    }

    var observers: [GeneralSourceCodeEditor] = []
    var textEncoding: String.Encoding = userPreferences.editorEncoding
    var mustSave = false
    var file: FSNode.File!
    var ioManager: Editor.IOManager!
    var isReadonly = false
    var saving = true

    func notifyFileMoved() {
        editorViewController.notifyFileMoved()
    }

    internal var editorViewController: EditorViewController! {
        session?.viewControllers[0] as? EditorViewController
    }

    internal var browserViewController: WebViewController! {
        session?.viewControllers[1] as? WebViewController
    }

    internal var consoleViewController: ConsoleViewController! {
        session?.viewControllers[2] as? ConsoleViewController
    }

    func editor(loaded editor: EditorViewController) {

    }

    func editor(shouldSaveFileNow editor: EditorViewController) -> Bool {
        if !mustSave {
            mustSave = true
            return true
        }
        return false
    }

    func editor(saveFile editor: EditorViewController) {
        saveFileLine()
        save()
    }

    func editor(toggledExpanderView editor: EditorViewController) {
        guard editorViewController.editorLoaded else {
            return
        }
        guard editorViewController.expand() else {
            return
        }
        for observer in observers {
            (observer as! WebEditorController).titleButton.toggleArrowAnimated()
        }
    }

    func editor(fallBackToASCII editor: EditorViewController) {
        textEncoding = .ascii
    }

    func editor(encodingFor editor: EditorViewController) -> String.Encoding {
        textEncoding
    }

    func editor(crashed editor: EditorViewController) {

    }

    func editor(closed editor: EditorViewController) {
        for observer in observers {
            observer.editor.closeTab()
        }
    }

    func toggleExpanderView() {
        editor(toggledExpanderView: editorViewController)
    }

    func observerClosed(observer: GeneralSourceCodeEditor!) {

        // Keep session from deallocating
        let session = session

        observer.die()
        observers.removeAll(where: { $0 == observer })

        guard observers.isEmpty else {
            return
        }

        if (file == nil) {
            return
        }
        editorViewController.stopFileReadingRequest()
        saveFileLine()
        userPreferences.statistics.save()
        if (!isReadonly) {
            save {
                FileBrowser.fileListUpdatedAt(url: self.file.url.deletingLastPathComponent())
            }
        }

        // Suppress 'unused variable' warning
        _ = session
    }

    internal func save(force: Bool = false, completion: (() -> ())? = nil) {
        guard let file = file else {
            completion?()
            return
        }

        if !mustSave && !force {
            completion?()
            return
        }

        mustSave = false

        getContent {
            result, error in

            func finish() {
                FileBrowser.fileMetadataChanged(file: file)
                completion?()
            }

            if error == nil, result != nil, var result = result as? String {
                let symbol = userPreferences.lineEndingSymbol.symbol
                if symbol != "\n" {
                    result = result.replacingOccurrences(of: "\n", with: userPreferences.lineEndingSymbol.symbol)
                }

                let data = result.data(using: self.textEncoding, allowLossyConversion: true)!

                file.setSavingState(state: .saving)

                FileBrowser.fileMetadataChanged(file: file)

                func setErrorSavingState() {
                    file.setSavingState(
                            state: .error(
                                    backup: .init(data: data, file: file, ioManager: self.ioManager)
                            )
                    )
                }

                self.ioManager.saveFileAt(url: file.url, data: data, completion: { error in
                    if error == nil {
                        file.setSavingState(state: .saved)
                    } else {
                        setErrorSavingState()
                    }
                    finish()
                })
            } else {
                file.setSavingState(state: .error(backup: nil))

                finish()
            }
        }
    }

    func getContent(completion: ((Any?, Error?) -> Void)? = nil) {
        if let webView = editorViewController.webView {
            webView.evaluateJavaScript("editor.getValue()") {
                (result: Any?, error: Error?) -> Void in
                completion?(result, error)
            }
        } else {
            completion?(nil, nil);
        }
    }

    private func saveFileLine() {

        editorViewController.webView?.evaluateJavaScript("[scrollDiv.scrollLeft, scrollDiv.scrollTop]") { (result, error) in

            if (error == nil) {
                if let scroll = result as? [Int] {
                    if (scroll[0] > 50 || scroll[1] > 50) {
                        self.file.setScrollPositionPoint(point: CGPoint(x: scroll[0], y: scroll[1]))
                        return
                    }
                }
            }
            self.file.setScrollPositionPoint(point: nil)
        }
    }
}
