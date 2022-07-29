//
//  AnotherFilePreviewController.swift
//  EasyHTML
//
//  Created by Артем on 10.03.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit
import WebKit

@available(iOS 11.0, *)
class WKURLSchemeHandlerLeakSafeWrapper: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        delegate?.webView(webView, start: urlSchemeTask)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        delegate?.webView(webView, stop: urlSchemeTask)
    }

    weak var delegate: WKURLSchemeHandler?

    init(delegate: WKURLSchemeHandler) {
        self.delegate = delegate
        super.init()
    }
}

class WKScriptMessageHandlerLeakSafeWrapper: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        delegate?.userContentController(
                userContentController, didReceive: message)
    }
}

class AnotherFilePreviewController: UIViewController, WKUIDelegate, WKScriptMessageHandler, WKNavigationDelegate, FileEditor, WKURLSchemeHandler, NotificationHandler {

    static let identifier = "another"

    var editor: Editor!

    final func handleMessage(message: EditorMessage, userInfo: Any?) {
        if case .close = message {
            ioManager.stopActivity()
        } else if case .fileMoved = message {
            title = (userInfo as! URL).lastPathComponent
        } else if case .focus = message {
            webView?.becomeFirstResponder()
        } else if case .blur = message {
            webView?.resignFirstResponder()
        }
    }

    final func canHandleMessage(message: EditorMessage) -> Bool {
        if case .close = message {
            return true
        }
        if case .fileMoved = message {
            return true
        }
        if case .focus = message {
            return true
        }
        if case .blur = message {
            return true
        }
        return false
    }

    internal let customURLScheme = "easyhtmlremotefile"

    func applyConfiguration(config: EditorConfiguration) {
        if let ioManager = config[.ioManager] as? Editor.IOManager {
            self.ioManager = ioManager
        }
        if let editor = config[.editor] as? Editor {
            self.editor = editor
        }
    }

    internal var ioManager = Editor.IOManager()
    internal var messageManager: EditorMessageViewManager! = nil
    internal var file: FSNode.File! = nil
    internal var webView: WKWebView! = nil
    internal var loadingInfoView = LoadingInfoView()

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        // Fallback
        if message.name == "EditorDidFinishLoad" {
            if #available(iOS 11.0, *) {

            } else {
                loadingInfoView.hide()
                webView.isHidden = false
            }
        }
    }

    @available(iOS 11.0, *)
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {

    }

    @available(iOS 11.0, *)
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let url = urlSchemeTask.request.url!

        var progress: ((Progress) -> ())?

        if (url.path == file.url.path) {
            let loadingInfo = localize("loadingstep_downloading", .editor)

            loadingInfoView.infoLabel.text = loadingInfo.replacingOccurrences(of: "#", with: "0")
            progress = {
                self.loadingInfoView.infoLabel.text = loadingInfo.replacingOccurrences(of: "#", with: String(Int($0.fractionCompleted * 100)))
            }
        }

        ioManager.readFileAt(url: url, completion: {
            data, error in

            let mimeType = MimeTypes.mimeTypes[url.pathExtension.lowercased()] ?? MimeTypes.DEFAULT_MIME_TYPE
            if let data = data {
                let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: -1, textEncodingName: nil)
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()

                if url.path == file.url.path {
                    loadingInfoView.hide()
                    self.webView.isHidden = false
                }
            } else {
                if (url.path == file.url.path) {
                    loadingErrorHandler(error: error)
                }
                if let error = error {
                    urlSchemeTask.didFailWithError(error)
                }
            }
        }, progress: progress)
    }

    func updateTheme() {

        view.backgroundColor = userPreferences.currentTheme.background
    }

    override func viewDidLoad() {

        super.viewDidLoad()

        guard editor != nil else {
            fatalError("Expected edtor")
        }

        view.backgroundColor = userPreferences.currentTheme.background
        edgesForExtendedLayout = []

        messageManager = EditorMessageViewManager(parent: self)

        file = editor.file

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        var scriptToInject = ""

        if #available(iOS 11.0, *) {
            let handler = WKURLSchemeHandlerLeakSafeWrapper(delegate: self)
            config.setURLSchemeHandler(handler, forURLScheme: customURLScheme)
        }

        scriptToInject += "EasyHTML.applicationLanguage=\"\(localize("local"))\";EasyHTML.deviceLanguage=\"\(NSLocale.current.languageCode ?? "en")\""

        let handler = WKScriptMessageHandlerLeakSafeWrapper(delegate: self)

        config.addScript(script: scriptToInject, scriptHandlerName: "EnableConsoleDriver", scriptMessageHandler: handler, injectionTime: .atDocumentStart)
        config.addScript(script: "webkit.messageHandlers.EditorDidFinishLoad.postMessage(1u);", scriptHandlerName: "EditorDidFinishLoad", scriptMessageHandler: handler, injectionTime: .atDocumentEnd)

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.navigationDelegate = self

        view.addSubview(webView)

        webView.isHidden = true
        webView.becomeFirstResponder()

        view.leftAnchor.constraint(equalTo: webView.leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: webView.rightAnchor).isActive = true
        view.topAnchor.constraint(equalTo: webView.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: webView.bottomAnchor).isActive = true

        view.addSubview(loadingInfoView)

        setupThemeChangedNotificationHandling()

        loadData()

        title = file.name
    }

    override func viewDidAppear(_ animated: Bool) {
        if navigationItem.rightBarButtonItem == nil {
            navigationItem.rightBarButtonItem = PrimarySplitViewControllerModeButton(window: view.window!)
        }
    }

    override func viewDidLayoutSubviews() {
        messageManager?.recalculatePositions()
    }

    @objc func loadData() {

        ioManager.stopActivity()

        messageManager.reset()

        let ext = file.url.pathExtension.lowercased()

        if #available(iOS 11.0, *) {
            guard
                    let encodedPath = file.url.path.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
                    let url = URL(string: customURLScheme + "://" + encodedPath)
            else {
                print("Invalid file url")
                return
            }

            let request = URLRequest(url: url)

            webView?.load(request)

        } else {
            if file.sourceType != .local && (ext == "html" || ext == "htm" || ext == "xml") {
                messageManager.newWarning(message: localize("remotefileopeningioswarning", .files))
                        .applyingStyle(style: .error)
                        .withCloseable(false)
                        .present()
                return
            }

            if (!file.url.path.hasPrefix(applicationPath)) {
                messageManager.newWarning(message: localize("unabletopreviewexternalfile"))
                        .applyingStyle(style: .error)
                        .withCloseable(false)
                        .present()
                return
            }

            let directoryUrl = URL(fileURLWithPath: applicationPath, isDirectory: true)

            webView?.loadFileURL(file.url, allowingReadAccessTo: directoryUrl)
        }

        loadingInfoView.fade()
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        WKAlertManager.presentAlert(message: message, on: PrimarySplitViewController.instance(for: view)!, completionHandler: completionHandler)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        WKAlertManager.presentConfirmPanel(message: message, on: PrimarySplitViewController.instance(for: view)!, completionHandler: completionHandler)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        WKAlertManager.presentInputPrompt(prompt: prompt, on: PrimarySplitViewController.instance(for: view)!, defaultText: defaultText, completionHandler: completionHandler)
    }

    internal func loadingErrorHandler(error: Error?) {

        ioManager.stopActivity()
        loadingInfoView.hide()

        let message = error?.localizedDescription ?? localize("downloaderror")

        messageManager.newWarning(message: localize("downloadknownerror") + "\n" + message)
                .applyingStyle(style: .error)
                .withCloseable(false)
                .withButton(EditorWarning.Button(title: localize("tryagain"), target: self, action: #selector(loadData)))
                .present()
    }

    deinit {
        webView?.stopLoading()
        webView?.uiDelegate = nil
        webView?.navigationDelegate = nil
        webView?.loadHTMLString("", baseURL: nil)
        webView = nil
    }
}
