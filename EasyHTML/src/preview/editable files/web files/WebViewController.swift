import UIKit
import WebKit

extension UIView {
    var firstResponder: UIView? {
        if isFirstResponder {
            return self
        }

        for view in subviews {
            if let firstResponder = view.firstResponder {
                return firstResponder
            }
        }

        return nil
    }
}

class WebViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate, WKURLSchemeHandler, NotificationHandler {

    internal let customURLScheme = "easyhtmlremotefile"

    var activityIndicator = UIActivityIndicatorView()
    var webView: WKWebView! = nil
    var messageManager: EditorMessageViewManager! = nil
    var dispatcher: WebEditorSessionDispatcher!

    internal var activeRequests = [URL: CancellableRequest]()

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: "r", modifierFlags: .command, action: #selector(reload), discoverabilityTitle: localize("reload"))
        ]
    }

    internal func cancelAllRequests() {
        for value in activeRequests.values {
            value.cancel()
        }
    }

    func webViewDidStartLoad(_ webView: UIWebView) {
        activityIndicator.startAnimating()
    }

    func updateTheme() {

        view.backgroundColor = userPreferences.currentTheme.background
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        WKAlertManager.presentAlert(message: message, on: view.window!.rootViewController!, completionHandler: completionHandler)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        WKAlertManager.presentConfirmPanel(message: message, on: view.window!.rootViewController!, completionHandler: completionHandler)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        WKAlertManager.presentInputPrompt(prompt: prompt, on: view.window!.rootViewController!, defaultText: defaultText, completionHandler: completionHandler)
    }

    @available(iOS 11.0, *)
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url, let request = activeRequests.removeValue(forKey: url) {
            request.cancel()
        }
    }

    @available(iOS 11.0, *)
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let url = urlSchemeTask.request.url!

        var request: CancellableRequest! = nil

        request = dispatcher.ioManager.readFileAt(url: url, completion: {
            data, error in

            activeRequests.removeValue(forKey: url)

            let mimeType = MimeTypes.mimeTypes[url.pathExtension.lowercased()] ?? MimeTypes.DEFAULT_MIME_TYPE
            if let data = data {

                let response = HTTPURLResponse.init(url: url, statusCode: 200, httpVersion: "3.0", headerFields: [
                    "Content-Type": mimeType,
                    "Content-Length": String(data.count),
                    "Accept-Ranges": "bytes"
                ])!

                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            } else {
                if (url.path == dispatcher.session!.file.url.path) {
                    handleLoadingError(error: error)
                }
                if let error = error {
                    urlSchemeTask.didFailWithError(error)
                }
            }
        })

        activeRequests[url] = request
    }

    private func handleLoadingError(error: Error?) {
        let message = error?.localizedDescription ?? localize("downloaderror")

        if let tabBarController = tabBarController as? WebEditorController {
            tabBarController.isExecuteButtonEnabled = true
            tabBarController.updateButton()
        }

        messageManager.newWarning(message: localize("downloadknownerror") + "\n" + message)
                .applyingStyle(style: .error)
                .withCloseable(false)
                .withButton(EditorWarning.Button(title: localize("tryagain"), target: self, action: #selector(reload)))
                .present()

        activityIndicator.stopAnimating()
    }

    override func viewDidLoad() {

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        messageManager = EditorMessageViewManager(parent: self)

        let config = WKWebViewConfiguration()

        if #available(iOS 11.0, *) {
            config.setURLSchemeHandler(WKURLSchemeHandlerLeakSafeWrapper(delegate: self), forURLScheme: customURLScheme)
        }

        var scriptToInject = readBundleFile(name: "consoledriver", ext: "js")!

        scriptToInject += ";EasyHTML.applicationLanguage=\"\(localize("local"))\";EasyHTML.deviceLanguage=\"\(NSLocale.current.languageCode ?? "en")\""

        let handler = WKScriptMessageHandlerLeakSafeWrapper(delegate: self)

        config.addScript(script: scriptToInject, scriptHandlerName: "EnableConsoleDriver", scriptMessageHandler: handler, injectionTime: .atDocumentStart)

        config.addScript(script: "webkit.messageHandlers.\(WebViewActions.didFinishLoadAction).postMessage(1);", scriptHandlerName: WebViewActions.didFinishLoadAction, scriptMessageHandler: handler, injectionTime: .atDocumentEnd)
        config.userContentController.add(handler, name: WebViewActions.consoleMessageAction)
        config.userContentController.add(handler, name: WebViewActions.consoleClearAction)
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: view.frame, configuration: config)
        view.addSubview(webView!)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self

        webView!.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        webView!.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        webView!.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        webView!.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        view.addSubview(activityIndicator)
        activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }

    override func didMove(toParent parent: UIViewController?) {
        tabBarItem?.image = UIImage(named: "browser")
    }

    @objc func reload() {

        cancelAllRequests()
        messageManager?.reset()

        guard let file = dispatcher.session?.file else {
            return
        }

        let ext = file.url.pathExtension.lowercased()

        if file.sourceType != .local && (ext == "html" || ext == "htm" || ext == "xml") {
            guard #available(iOS 11.0, *) else {
                messageManager.newWarning(message: localize("remotefileopeningioswarning", .files))
                        .applyingStyle(style: .error)
                        .withCloseable(false)
                        .present()
                return
            }
        }

        if #available(iOS 11.0, *) {

        } else {

            if (!file.url.path.hasPrefix(applicationPath)) {
                messageManager.newWarning(message: localize("unabletopreviewexternalfile"))
                        .applyingStyle(style: .error)
                        .withCloseable(false)
                        .present()
                return
            }
        }

        dispatcher.consoleViewController?.clearConsole()
        dispatcher.consoleViewController?.isLoaded = true

        view.bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date, completionHandler: {})

        webView?.layoutIfNeeded()

        if (dispatcher.isBrowser) {

            UIView.animate(withDuration: 0.5) {
                self.webView?.alpha = 0.2
            }

            dispatcher.save {
                if #available(iOS 11.0, *) {
                    let url = URL(string: self.customURLScheme + "://" + file.url.path.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)!

                    let request = URLRequest(url: url)

                    self.webView?.load(request)
                } else {
                    let directoryUrl = URL(fileURLWithPath: applicationPath, isDirectory: true)

                    self.webView?.loadFileURL(file.url, allowingReadAccessTo: directoryUrl)
                }
            }
        } else if (dispatcher.isScript && !dispatcher.isWebpage) {
            dispatcher.save {
                self.webView?.loadHTMLString("<html></html>", baseURL: file.url)
            }
        }
    }

    func parseJavaScriptAttributedString(origin: String, colorInfo: String) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString(string: origin)

        let items = colorInfo.split(separator: ";");

        let colors: [UIColor] = ConsoleViewController.activeColorScheme

        let cursiveFont = ConsoleViewController.fontItalic
        var location = 0

        attributedString.beginEditing()

        let paragraphStyle = NSMutableParagraphStyle()

        paragraphStyle.headIndent = 10

        attributedString.addAttributes([
            .font: ConsoleViewController.font,
            .foregroundColor: userPreferences.currentTheme.cellTextColor,
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: origin.count))

        for i in stride(from: 0, to: items.count - 1, by: 2) {
            let color = Int(items[i])!
            var length = Int(items[i + 1])!
            let cursive = length < 0
            if (cursive) {
                length = -length
            }

            if (color == -1 && !cursive) {
                // Avoid setting any attributes that we don't need to save memory
                location += length
                continue
            }

            var attributes = [NSAttributedString.Key: Any]()

            if (color != -1) {
                attributes[.foregroundColor] = colors[color]
            }

            if (cursive) {
                attributes[.font] = cursiveFont
            }

            attributedString.addAttributes(attributes, range: NSRange(location: location, length: length))
            location += length
        }

        attributedString.endEditing()

        return attributedString
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case WebViewActions.consoleClearAction:
            dispatcher.consoleViewController?.clearConsole()
            break;
        case WebViewActions.consoleMessageAction:
            if dispatcher.consoleViewController.view.window == nil {
                dispatcher.consoleViewController?.unreadMessagesCount += 1
            }

            guard let body = message.body as? [Any] else {
                return
            }
            if (body.count != 3) {
                return
            }
            guard let message = body[0] as? String else {
                return
            }
            guard let type = body[1] as? Int else {
                return
            }
            guard let colorInfo = body[2] as? String else {
                return
            }

            let attributedString = parseJavaScriptAttributedString(origin: message, colorInfo: colorInfo)

            dispatcher.consoleViewController?.addMessage(message: ConsoleMessage(body: attributedString, type: type))
        case WebViewActions.didFinishLoadAction:

            webView.alpha = 1.0

            func setupView() {
                activityIndicator.stopAnimating()
                if let tabBarController = tabBarController as? WebEditorController {
                    tabBarController.isExecuteButtonEnabled = true
                }
            }

            if (dispatcher.isScript && !dispatcher.isWebpage) {
                dispatcher.getContent {
                    response, _ in
                    guard let content = response as? String else {
                        return
                    }
                    self.webView?.evaluateJavaScript(content, completionHandler: nil)
                    setupView()
                }
            } else {
                setupView()
            }

                //print("loading complete")

        default: break;
        }
    }

    func navigatedToPreview() {
        focus()

        if dispatcher.consoleViewController?.isLoaded != true {
            reload()
        }
    }

    func focus() {
        webView.becomeFirstResponder()
    }

    deinit {
        webView?.stopLoading()
        webView?.uiDelegate = nil
        webView?.navigationDelegate = nil
        webView?.loadHTMLString("", baseURL: nil)
        webView = nil
        cancelAllRequests()
    }
}
