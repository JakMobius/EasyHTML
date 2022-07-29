//
//  GitHubRepositoryReadmeCell.swift
//  EasyHTML
//
//  Created by Артем on 01/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit
import Alamofire
import WebKit

extension GitHubRepositoryController {
    class ReadMeCell: UITableViewCell, NotificationHandler, WKScriptMessageHandler, WKNavigationDelegate {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            updateWebViewColor()
        }
        
        func updateWebViewColor() { contents.evaluateJavaScript("window.dark=\(userPreferences.currentTheme.isDark);document.body.className=window.dark?'dark-ui':''", completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
            
            switch navigationAction.navigationType {
            case .linkActivated:
                if #available(iOS 11.0, macOS 10.13, *) {
                    if let scheme = url.scheme, webView.configuration.urlSchemeHandler(forURLScheme: scheme) != nil {
                        decisionHandler(.allow)
                        return
                    }
                }
                
                decisionHandler(.cancel)
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url)
                } else {
                    UIApplication.shared.openURL(url)
                }
            default:
                decisionHandler(.allow)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loading = false
            hideActivityIndicator()
            fetchHeight()
            contents.isHidden = false
            
            contents.alpha = 0
            
            UIView.animate(withDuration: 0.2, delay: 0.1, animations: {
                self.contents.alpha = 1
            }, completion: nil)
        }
        
        override var backgroundColor: UIColor? {
            set {
                // Фигушки
            }
            get {
                return userPreferences.currentTheme.cellColor1
            }
        }
        
        var contents: WKWebView!
        var loadTask: DataRequest?
        var activityIndicator: UIActivityIndicatorView!
        var errorLabel: UILabel!
        var height: CGFloat = 50
        var webViewBodyHeight: CGFloat = 0
        var repoName: String!
        var branchName: String!
        var loading = false
        
        func showErrorLabel(text: String) {
            errorLabel = UILabel()
            errorLabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(errorLabel)
            errorLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
            errorLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
            errorLabel.font = UIFont.systemFont(ofSize: 14)
            errorLabel.text = text
            errorLabel.textColor = userPreferences.currentTheme.secondaryTextColor
            errorLabel.numberOfLines = -1
            errorLabel.textAlignment = .center
            errorLabel.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, constant: -20).isActive = true
            errorLabel.frame.size = errorLabel.sizeThatFits(CGSize(width: contentView.frame.width - 20, height: CGFloat.greatestFiniteMagnitude))
            
            errorLabel.alpha = 0
            UIView.animate(withDuration: 0.2, delay: 0.2, animations: {
                self.errorLabel?.alpha = 1
            }, completion: nil)
            
            fetchHeight()
        }
        
        func updateTableview() {
            
            // Окей, да, это нарушение правил MVVC.
            // но как иначе быть, если UITableView
            // не предоставляет нативных способов
            // обновить высоту ячейки?
            
            // А делать делегат-протокол мне лень.
            // TODO, наверное...
            
            let tableView = (self.parentViewController as? GitHubRepositoryController)?.tableView
            tableView?.beginUpdates()
            tableView?.endUpdates()
        }
        
        func hideActivityIndicator() {
            self.activityIndicator?.removeFromSuperview()
            self.activityIndicator = nil
        }
        
        func setMarkdownString(string: String) {
            do {
                let url = Bundle.main.url(forResource: "github-markdown", withExtension: "html")!
                let base = try String(contentsOf: url)
                let baseURL = URL(string: "https://raw.githubusercontent.com/\(self.repoName!)/\(self.branchName!)/")
                
                let html = base.replacingOccurrences(of: "DOWN_HTML", with: string)
                
                contents.loadHTMLString(html, baseURL: baseURL)
                
            } catch {
                showErrorLabel(text: error.localizedDescription)
            }
        }
        
        func fetchHeight() {
            if self.errorLabel != nil {
                let height = max(50, self.errorLabel.frame.height + 10)
                if height != self.height {
                    self.height = height
                    self.updateTableview()
                }
                return
            }
            if self.loading {
                if 50 != self.height {
                    self.height = 50
                    self.updateTableview()
                }
                return
            }
            
            self.contents?.evaluateJavaScript(
                "var b=document.body;if(b&&b.lastElementChild)b.lastElementChild.getBoundingClientRect().bottom;else 30",
                completionHandler: { (result, error) in
                    self.webViewBodyHeight = result as! CGFloat
                    let newHeight = self.webViewBodyHeight / 2 + 20
                    if newHeight != self.height {
                        self.height = newHeight
                        self.updateTableview()
                    }
                    
            })
        }
        
        func loadFile() {
            if self.contents == nil {
                initContents()
            }
            self.loading = true
            self.contents.isHidden = true
            
            errorLabel?.removeFromSuperview()
            errorLabel = nil
            
            self.fetchHeight()
            
            activityIndicator = UIActivityIndicatorView()
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(activityIndicator)
            contentView.centerXAnchor.constraint(equalTo: activityIndicator.centerXAnchor).isActive = true
            contentView.centerYAnchor.constraint(equalTo: activityIndicator.centerYAnchor).isActive = true
            updateTheme()
            activityIndicator.startAnimating()
            
            let path = "https://api.github.com/repos/\(repoName!)/readme"
            let headers = [
                "Accept":"application/vnd.github.v3.html"
            ]
            
            self.loadTask = Alamofire.request(path, headers: headers).responseData { (response) in
                self.loadTask = nil
                let result = response.result
                
                guard let httpResponse = response.response else {
                    self.showErrorLabel(text: localize("errorunknown", .github))
                    return
                }
                
                if let error = GitHubUtils.checkAPIResponse(response: httpResponse) {
                    self.hideActivityIndicator()
                    if case GitHubError.notFound = error {
                        self.showErrorLabel(text: localize("noreadme", .github))
                        return
                    }
                    
                    self.showErrorLabel(text: error.localizedDescription)
                    return
                }
                
                result.ifFailure {
                    let error = result.error!
                    
                    self.hideActivityIndicator()
                    self.loading = false
                    
                    self.showErrorLabel(text: error.localizedDescription)
                }
                
                result.ifSuccess {
                    let data = try! result.unwrap()
                    guard let string = String(data: data, encoding: .utf8) else {
                        // TODO: Локализовать это всё
                        self.showErrorLabel(text: localize("errorunknown", .github))
                        return
                    }
                    
                    self.setMarkdownString(string: string)
                }
            }
        }
        
        func updateTheme() {
            
            if userPreferences.currentTheme.isDark {
                activityIndicator?.style = .white
            } else {
                activityIndicator?.style = .gray
            }
            
            if !self.loading {
                updateWebViewColor()
            }
        }
        
        func initContents() {
            
            let configuration: WKWebViewConfiguration! = .init()
            
            configuration.addScript(
                script: "webkit.messageHandlers.dark.postMessage(true)",
                scriptHandlerName: "dark",
                scriptMessageHandler: WKScriptMessageHandlerLeakAvoider(delegate: self),
                injectionTime: .atDocumentEnd
            )
            
            contents = WKWebView(frame: .zero, configuration: configuration)
            contents.navigationDelegate = self
            contents.translatesAutoresizingMaskIntoConstraints = false
            contents.scrollView.maximumZoomScale = 1.0
            contents.scrollView.minimumZoomScale = 1.0
            contents.scrollView.isScrollEnabled = false
            contents.scrollView.panGestureRecognizer.isEnabled = false
            contentView.addSubview(contents)
            contents.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
            contents.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
            contents.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
            contents.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
        }
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            
            setupThemeChangedNotificationHandling()
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
        
        deinit {
            loadTask?.cancel()
        }
    }
}
