

import UIKit
import WebKit

/// Кнопка, самостоятельно отслеживающая события
/// смены цветовой темы, и устанавливающая свой цвет в тёмный

internal class DarkButton: UIButton, NotificationHandler {
    func standardInitialise() {
        setupThemeChangedNotificationHandling()
        
        tintColor = userPreferences.currentTheme.buttonDarkColor
        imageView?.tintColor = userPreferences.currentTheme.buttonDarkColor
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        standardInitialise()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        standardInitialise()
    }
    
    func updateTheme() {
        
        tintColor = userPreferences.currentTheme.buttonDarkColor
        imageView?.tintColor = userPreferences.currentTheme.buttonDarkColor
    }
    
    deinit {
        clearNotificationHandling()
    }
}

internal class FindReplaceDialogMessage: UIImageView {
    
    internal enum MessageActionType {
        case goToEnd, goToStart
    }
    
    private let parent: UIView
    private let type: MessageActionType
    
    internal init(parent: UIView, type: MessageActionType) {
        self.parent = parent
        self.type = type
        super.init(frame: parent.frame)
        parent.addSubview(self)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = userPreferences.currentTheme.cellSelectedColor;
        self.layer.cornerRadius = 10.0
        
        self.image = self.type == .goToEnd ? #imageLiteral(resourceName: "jump-to-end").withRenderingMode(.alwaysTemplate) : #imageLiteral(resourceName: "jump-to-start").withRenderingMode(.alwaysTemplate)
        self.contentMode = .center
        self.contentScaleFactor = 4.0
        self.tintColor = userPreferences.currentTheme.secondaryTextColor
        
        parent.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        parent.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.widthAnchor.constraint(equalToConstant: 100.0).isActive = true
        self.heightAnchor.constraint(equalToConstant: 100.0).isActive = true
        
        self.isUserInteractionEnabled = false
        self.alpha = 0.0
    }
    
    internal func present() {
        
        self.transform = CGAffineTransform(translationX: 0.8, y: 0.8)
        
        self.alpha = 1.0
        
        UIView.animate(withDuration: 1.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.curveEaseOut], animations: {
            self.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            self.alpha = 0.0
        }, completion: {
            _ in
            self.removeFromSuperview()
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}

@objc protocol FindReplaceDialogDelegate {
    @objc optional func findReplaceDialog(_ dialog: FindReplaceDialogContainerView, scrolledTo x: Int, _ y: Int)
    @objc optional func findReplaceDialog(willClose dialog: FindReplaceDialogContainerView, animated: Bool)
}

class FindReplaceDialogContainerView: UIView, UITextFieldDelegate, NotificationHandler {
    
    internal enum ButtonActionType {
        case search, replace
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(findNext)),
            UIKeyCommand(input: "\r", modifierFlags: .shift, action: #selector(findPrevious))
        ]
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    internal weak var delegate: FindReplaceDialogDelegate!
    private let parent: UIView
    private let fakeButton = UIButton()
    private var searchField: UITextField!
    private var replaceField: UITextField!
    private var sourceTappedButton: UIButton!
    let type: ButtonActionType
    private let webView: WKWebView
    private var step = 0
    internal var searchText = "" {
        didSet {
            escapedSearchText = EditorViewController.getEscapedJavaScriptString(searchText)
        }
    }
    private var escapedSearchText = ""
    internal var replaceText = "" {
        didSet {
            escapedReplaceText = EditorViewController.getEscapedJavaScriptString(replaceText)
        }
    }
    private var escapedReplaceText = ""
    
    private var splitButtonConstraint: NSLayoutConstraint!
    private var splitButtonSecondaryConstraint: NSLayoutConstraint!
    private var replaceDialogWillHideSoon = false
    private var isCompact = false
    
    private var replaceAllButton: UIButton!
    private var replaceButton: UIButton!
    private var closeButtonView: DarkButton!
    private var previousOccurenceButton: DarkButton!
    private var nextOccurenceButton: DarkButton!
    
    override func layoutSubviews() {
        if let splitButtonConstraint = splitButtonConstraint, let splitButtonSecondaryConstraint = splitButtonSecondaryConstraint {
            if(self.frame.width < 500 && !replaceDialogWillHideSoon) {
                splitButtonConstraint.isActive = false
                splitButtonSecondaryConstraint.isActive = true
                fakeButton.isHidden = true
                matchesFoundView.isHidden = true
                
                isCompact = true
            } else {
                splitButtonConstraint.isActive = true
                splitButtonSecondaryConstraint.isActive = false
                fakeButton.isHidden = false
                matchesFoundView.isHidden = false
                
                isCompact = false
            }
        }
        
        super.layoutSubviews()
    }
    
    private var matchesFound: Int = 0 {
        didSet {
            if(matchesFound == -1) {
                return
            }
            
            if(matchesFound > 2000) {
                matchesFoundView.text = localize("occurencesfound", .editor).replacingOccurrences(of: "#", with: "> 2000")
            } else if(matchesFound == 0) {
                matchesFoundView.text = localize("nooccurrencesfound", .editor)
            } else {
                matchesFoundView.text = localize("occurencesfound", .editor).replacingOccurrences(of: "#", with: "\(matchesFound)")
            }
        }
    }
    private var matchesFoundView = UILabel()
    
    internal init(parent: UIView, type: ButtonActionType, webView: WKWebView) {
        self.parent = parent
        self.type = type
        self.webView = webView
        super.init(frame: parent.bounds)
        parent.addSubview(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        parent.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        parent.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        parent.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        parent.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        setupThemeChangedNotificationHandling()
    }
    
    func updateTheme() {
        matchesFoundView.textColor = userPreferences.currentTheme.secondaryTextColor
        searchField.textColor = userPreferences.currentTheme.cellTextColor
        searchField.attributedPlaceholder = NSAttributedString(
            string: localize(type == .search ? "search" : "replace", .editor),
            attributes: [.foregroundColor : userPreferences.currentTheme.secondaryTextColor]
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    @objc private func closeButtonAction() {
        close(animated: true)
    }
    
    internal func close(animated: Bool) {
        self.fakeButton.isHidden = false
        
        delegate?.findReplaceDialog?(willClose: self, animated: animated)

        webView.evaluateJavaScript("editor.highlightSearch(editor,'');window.searchMarker&&window.searchMarker.clear()", completionHandler: nil)
        
        if animated {
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .curveEaseInOut, animations: {
                self.fakeButton.alpha = 1.0
                self.fakeButton.frame = self.sourceTappedButton.convert(self.sourceTappedButton.bounds, to: self.parent)
            }, completion: nil)
            UIView.animate(withDuration: 1.0, delay: 0.0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.0, options: [], animations: {
                self.closeButtonView.alpha = 0.0
                self.closeButtonView.transform = CGAffineTransform(scaleX: 0.4, y: 0.4).rotated(by: 1.5)
            }, completion: {
                _ in
                self.sourceTappedButton.addSubview(self.sourceTappedButton.imageView!)
                self.sourceTappedButton.isHidden = false
                self.closeButtonView.removeFromSuperview()
                self.fakeButton.removeFromSuperview()
                
                if self.searchingStarted {
                    self.replaceAllButton?.removeFromSuperview()
                    self.replaceButton?.removeFromSuperview()
                    self.previousOccurenceButton?.removeFromSuperview()
                    self.nextOccurenceButton?.removeFromSuperview()
                } else {
                    self.searchField.removeFromSuperview()
                    self.replaceField?.removeFromSuperview()
                }
                
                self.removeFromSuperview()
            })
            UIView.animate(withDuration: 1.0, delay: 0.0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.0, options: [], animations: {
                
                func fade(_ view: UIView?) {
                    guard view != nil else { return }
                    view!.alpha = 0.0
                    view!.transform = CGAffineTransform(translationX: 0, y: -30)
                 }
                
                if self.searchingStarted {
                    fade(self.replaceAllButton)
                    fade(self.replaceButton)
                    fade(self.previousOccurenceButton)
                    fade(self.nextOccurenceButton)
                    fade(self.matchesFoundView)
                } else {
                    fade(self.searchField)
                    fade(self.replaceField)
                }
            }, completion: nil)
        } else {
            self.sourceTappedButton.addSubview(self.sourceTappedButton.imageView!)
            self.sourceTappedButton.isHidden = false
            self.closeButtonView?.removeFromSuperview()
            self.fakeButton.removeFromSuperview()
            self.replaceButton?.removeFromSuperview()
            self.replaceAllButton?.removeFromSuperview()
            self.searchField.removeFromSuperview()
            self.replaceField?.removeFromSuperview()
            self.previousOccurenceButton?.removeFromSuperview()
            self.nextOccurenceButton?.removeFromSuperview()
            
            
            self.removeFromSuperview()
        }
    }
    
    @objc private func replaceSelected() {
        webView.evaluateJavaScript("""
            (function(){
            var s=searchCursor;
            if(s.atOccurrence){
                var isok=false;
                editor.replaceRange(\"\(escapedReplaceText)\",s.pos.from,s.pos.to, "+replace");
                window.searchMarker.clear();
                if(!s.findNext()){
                    s.pos.from=s.pos.to={line:0,ch:0};
                    isok=s.findNext()}
                else isok=true;
                if(isok){
                    window.searchMarker=editor.doc.markText(s.pos.from,s.pos.to,{className:'search-marked-text'});
                    editor.setSelection(s.pos.from,s.pos.to);
                    scrollToElement(document.querySelector('.search-marked-text'))
            }};
            return[scrollDiv.scrollLeft,scrollDiv.scrollTop]
            })()
            """, completionHandler: {
            result, error in
            if let result = result as? [Int] {
                let x = result[0]
                let y = result[1]
                
                self.delegate?.findReplaceDialog?(self, scrolledTo: x, y)
            }
        })
    }
    
    internal func updateSearchResults() {
        guard !replaceDialogWillHideSoon else { return }
        webView.evaluateJavaScript("""
            (function(){
            var q=editor.getSearchCursor(\"\(escapedSearchText)\",editor.state.query),i=0;while(q.findNext()&&++i<=2000);
            if(window.searchMarker)window.searchMarker.clear()
            return i
            })()
        """) { result, error in
            if let result = result as? Int {
                self.matchesFound = result
            }
        }
    }
    
    @objc private func replaceAll() {
        
        if self.isCompact {
            self.matchesFoundView.transform = CGAffineTransform(translationX: 0, y: 30)
            self.matchesFoundView.isHidden = false
            self.matchesFoundView.alpha = 0
            self.fakeButton.isHidden = false
            self.fakeButton.transform = CGAffineTransform(translationX: -50, y: 0)
        }
        
        UIView.animate(withDuration: 0.5) {
            func hide(_ view: UIView!) {
                guard view != nil else { return }
                
                view.transform = CGAffineTransform(translationX: 0, y: -30)
                view.alpha = 0
            }
            
            hide(self.previousOccurenceButton)
            hide(self.nextOccurenceButton)
            hide(self.replaceAllButton)
            hide(self.replaceButton)
            
            if self.isCompact {
                self.matchesFoundView.transform = .identity
                self.matchesFoundView.alpha = 1
                self.fakeButton.transform = .identity
            }
        }
        
        replaceDialogWillHideSoon = true
        
        self.matchesFoundView.text = localize("replacing", .editor)
        
        webView.evaluateJavaScript("editor.operation(function(){var l=editor.lineCount()-1,s=searchCursor;if(l>-1){s.pos.from=s.pos.to={line:l,ch:editor.getLine(l).length}}var i=0;while(s.findPrevious()) {editor.replaceRange(\"\(escapedReplaceText)\",s.pos.from,s.pos.to,'+replace');i+=1}return i})", completionHandler: {
            result, error in
            self.matchesFound = -1
            if let result = result {
                self.matchesFoundView.text = localize("replacednumber", .editor).replacingOccurrences(of: "#", with: "\(result)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0, execute: {
                self.close(animated: true)
            })
        })
    }
    
    private var searchingStarted = false
    
    private func selectField(_ field: UITextField) {
        field.selectedTextRange = field.textRange(
            from: field.beginningOfDocument,
            to: field.endOfDocument
        )
    }
    
    @objc func focus() {
        
        if self.step == 0 && !self.searchingStarted {
            searchField.becomeFirstResponder()
            searchField.text = searchText
            selectField(searchField)
            highlightResultsForPattern()
            return
        }
        
        webView.evaluateJavaScript("searchMarker.clear()")
        
        let step = self.step
        let searchingStarted = self.searchingStarted
        
        self.step = 0
        self.searchingStarted = false
        
        searchField.isHidden = false
        searchField.transform = .init(translationX: 0, y: -40)
        searchField.becomeFirstResponder()
        searchField.text = searchText
        selectField(searchField)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
            self.searchField.transform = .identity
            self.searchField.alpha = 1.0
            
            if searchingStarted {
                self.matchesFoundView.transform = .init(translationX: 0, y: 40)
                
                self.nextOccurenceButton?.alpha = 0
                self.previousOccurenceButton?.alpha = 0
                
                if self.type == .replace {
                    self.replaceButton?.alpha = 0
                    self.replaceAllButton?.alpha = 0
                }
            } else if step == 1 {
                self.replaceField.transform = .init(translationX: 0, y: 40)
            }
        }) { _ in
            if searchingStarted {
                self.matchesFoundView.isHidden = true
                
                self.nextOccurenceButton?.isHidden = true
                self.previousOccurenceButton?.isHidden = true
                
                if self.type == .replace {
                    self.replaceButton?.isHidden = true
                    self.replaceAllButton?.isHidden = true
                }
            }
        }
    }
    
    func configureTextField(_ field: UITextField) {
        field.textColor = userPreferences.currentTheme.cellTextColor
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 11.0, *) {
            field.smartDashesType = .no
            field.smartQuotesType = .no
        }
    }
    
    func search() {
        
        var delay = 0.0
        
        func layout(_ view: UIView?) {
            guard let view = view else { return }
            self.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            self.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        }
        
        func fadeIn(_ view: UIView?) {
            guard let view = view else { return }
            
            view.translatesAutoresizingMaskIntoConstraints = false
            view.transform = .init(translationX: 0, y: 40)
            view.alpha = 0.0
            
            UIView.animate(withDuration: 0.4, delay: delay, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: [], animations: {
                view.transform = .identity
                view.alpha = 1.0
            }, completion: nil)
            
            delay += 0.2
        }
        
        if(previousOccurenceButton == nil) {
            func setupButton(rotation: CGFloat, action: Selector) -> DarkButton {
                let button = DarkButton(type: .system)
                
                button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                button.imageView!.contentMode = .center
                button.imageView!.contentMode = .center
                button.imageView!.transform = CGAffineTransform(rotationAngle: rotation)
                button.setImage(#imageLiteral(resourceName: "expand").withRenderingMode(.alwaysTemplate), for: .normal)
                button.imageView!.tintColor = userPreferences.currentTheme.buttonDarkColor
                button.tintColor = userPreferences.currentTheme.buttonDarkColor
                button.addTarget(self, action: action, for: .touchUpInside)
                
                addSubview(button)
                
                return button
            }
            
            previousOccurenceButton = setupButton(rotation: 1.57, action: #selector(findPrevious))
            nextOccurenceButton = setupButton(rotation: 4.71, action: #selector(findNext))
            
            previousOccurenceButton.addTarget(self, action: #selector(findPrevious), for: .touchUpInside)
            nextOccurenceButton.addTarget(self, action: #selector(findNext), for: .touchUpInside)
            
            nextOccurenceButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -40.0).isActive = true
            previousOccurenceButton.rightAnchor.constraint(equalTo: nextOccurenceButton.leftAnchor, constant: -5.0).isActive = true
            nextOccurenceButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
            previousOccurenceButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
            
            addSubview(matchesFoundView)
            matchesFoundView.minimumScaleFactor = 0.8
            matchesFoundView.adjustsFontSizeToFitWidth = true
            matchesFoundView.text = localize("searching", .editor)
            matchesFoundView.textColor = userPreferences.currentTheme.secondaryTextColor
            
            matchesFoundView.leftAnchor.constraint(equalTo: leftAnchor, constant: 45).isActive = true
            matchesFoundView.rightAnchor.constraint(equalTo: rightAnchor, constant: -110).isActive = true
            
            func setupReplaceButton(title: String, action: Selector) -> UIButton {
                let button = UIButton(type: .system)
                
                button.addTarget(self, action: action, for: .touchUpInside)
                button.setTitle(localize(title, .editor), for: .normal)
                button.tintColor = UIColor.white
                addSubview(button)
                
                return button
            }
            
            if(type == .replace) {
                replaceButton = setupReplaceButton(title: "replacesingle", action: #selector(replaceSelected))
                replaceAllButton = setupReplaceButton(title: "replaceall", action: #selector(replaceAll))
                
                splitButtonConstraint = replaceAllButton.rightAnchor.constraint(equalTo: previousOccurenceButton.leftAnchor, constant: -10.0)
                splitButtonSecondaryConstraint = replaceButton.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 10.0)
                splitButtonSecondaryConstraint.isActive = false
                
                addConstraints([
                    splitButtonConstraint,
                    replaceButton.rightAnchor.constraint(equalTo: replaceAllButton.leftAnchor, constant: -1.0),
                    replaceAllButton.widthAnchor.constraint(equalToConstant: 80.0),
                    replaceButton.widthAnchor.constraint(equalToConstant: 80.0),
                    ])
                
                replaceButton.layer.mask = CAShapeLayer.getRoundedRectShape(frame: CGRect(x: 0, y: 7.5, width: 80, height: 25), roundingCorners: [.topLeft, .bottomLeft], withRadius: 20)
                replaceButton.layer.backgroundColor = UIColor(white: 0.5, alpha: 0.7).cgColor
                
                replaceAllButton.layer.mask = CAShapeLayer.getRoundedRectShape(frame: CGRect(x: 0, y: 7.5, width: 80, height: 25), roundingCorners: [.bottomRight, .topRight], withRadius: 20)
                replaceAllButton.layer.backgroundColor = UIColor(white: 0.5, alpha: 0.7).cgColor
            }
            
            layout(matchesFoundView)
            layout(replaceButton)
            layout(replaceAllButton)
            layout(previousOccurenceButton)
            layout(nextOccurenceButton)
        } else {
            previousOccurenceButton?.isHidden = false
            nextOccurenceButton?.isHidden = false
            replaceButton?.isHidden = false
            replaceAllButton?.isHidden = false
            matchesFoundView.isHidden = false
        }
        
        fadeIn(matchesFoundView)
        fadeIn(replaceButton)
        fadeIn(replaceAllButton)
        fadeIn(previousOccurenceButton)
        fadeIn(nextOccurenceButton)
        
        layoutSubviews()
        
        webView.evaluateJavaScript("""
            (function(){
            var s=editor.getSearchCursor(\"\(escapedSearchText)\",editor.state.query,\(!userPreferences.searchIsCaseSensitive)),i=0
            while(i<=2001&&s.findNext()){
            i++
            }
            if(i > 0) {
            s.pos.from=s.pos.to=editor.getCursor()
            if(!s.findNext()){
            s.pos.from = s.pos.to = {line: 0, ch: 0}
            s.findNext()
            }
            window.searchMarker=editor.doc.markText(s.pos.from,s.pos.to,{className:"search-marked-text"})
            editor.setSelection(s.pos.from,s.pos.to)
            scrollToElement(document.querySelector(".search-marked-text"))
            }
            window.searchCursor=s
            return [i,scrollDiv.scrollLeft,scrollDiv.scrollTop]
            })()
            """, completionHandler: {
                result, error in
                if let error = error {
                    print("[EasyHTML] Searching error: \(error)")
                    self.matchesFoundView.text = localize("searchingerror", .editor)
                }
                if let result = result as? [Int] {
                    self.matchesFound = result[0]
                    
                    let x = result[1]
                    let y = result[2]
                    
                    self.delegate?.findReplaceDialog?(self, scrolledTo: x, y)
                    
                    self.searchingStarted = true
                }
        })
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        findNext()
        return true
    }
    
    @objc func findNext() {
        
        guard self.searchingStarted else {
            nextStep()
            return
        }
        
        webView.evaluateJavaScript("""
            (function(){
            var l=0,w=window,s=window.searchCursor
            if(!s.findNext()) {
                var m=editor.lineCount()-1
                if(m>-1){
                    s.pos.from=s.pos.to={line:0,ch:0}
                    searchCursor.findNext()
                }
                l=1
            }
            if(s.from()) {
                w.searchMarker.clear()
                w.searchMarker=editor.doc.markText(s.pos.from,s.pos.to,{className:"search-marked-text"})

                editor.setSelection(s.pos.from,s.pos.to)
                scrollToElement(document.querySelector(".search-marked-text"));
                return[l,scrollDiv.scrollLeft,scrollDiv.scrollTop]
            } else {
                return[-1,scrollDiv.scrollLeft,scrollDiv.scrollTop]
            }
            })()
            """, completionHandler: {
                result, error in
                if let result = result as? [Int] {
                    if(result[0] == -1) {
                        self.matchesFound = 0
                    } else if(result[0] == 1) {
                        FindReplaceDialogMessage(parent: self.webView.superview!, type: .goToStart).present()
                    }
                    
                    let x = result[1]
                    let y = result[2]
                    
                    self.delegate?.findReplaceDialog?(self, scrolledTo: x, y)
                }
        })
    }
    
    @objc func findPrevious() {
        
        guard self.searchingStarted else {
            return
        }
        
        webView.evaluateJavaScript("""
            (function(){
            var l=0,w=window,s=searchCursor
            if(!s.findPrevious()) {
                var m=editor.lineCount()-1
                if(m>-1) {
                    s.pos.from=s.pos.to={
                        line:m,
                        ch:editor.getLine(m).length
                    }
                    s.findPrevious()
                }
                l=1
            }
            if(s&&s.pos.from) {
                w.searchMarker.clear()
                w.searchMarker=editor.doc.markText(s.pos.from,s.pos.to,{className:"search-marked-text"})
                editor.setSelection(s.pos.from,s.pos.to)
                scrollToElement(document.querySelector(".search-marked-text"));
                return[l,scrollDiv.scrollLeft,scrollDiv.scrollTop]
            } else {
                return[-1,scrollDiv.scrollLeft,scrollDiv.scrollTop]
            }
            })()
            """, completionHandler: {
                result, error in
                if let result = result as? [Int] {
                    if(result[0] == -1) {
                        self.matchesFound = 0
                    } else if(result[0] == 1) {
                        FindReplaceDialogMessage(parent: self.webView.superview!, type: .goToEnd).present()
                    }
                    
                    let x = result[1]
                    let y = result[2]
                    
                    self.delegate?.findReplaceDialog?(self, scrolledTo: x, y)
                }
        })
    }
    
    func highlightResultsForPattern() {
        
        webView.evaluateJavaScript("""
            editor.highlightSearch(editor, \"\(escapedSearchText)\",\(!userPreferences.searchIsCaseSensitive))
            """, completionHandler: nil)
    }
    
    internal func present(tapedButton button: UIButton, animated: Bool) {
        
        sourceTappedButton = button
        
        button.isHidden = true
        
        fakeButton.setImage(button.image(for: .normal), for: .normal)
        fakeButton.imageView!.tintColor = userPreferences.currentTheme.buttonDarkColor
        fakeButton.imageView!.contentMode = .scaleAspectFit
        fakeButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        fakeButton.addTarget(self, action: #selector(focus), for: .touchUpInside)
        
        fakeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fakeButton)
        
        searchField = UITextField()
        
        configureTextField(searchField)
        
        searchField.attributedPlaceholder = NSAttributedString(
            string: localize(type == .search ? "search" : "replace", .editor),
            attributes: [.foregroundColor : userPreferences.currentTheme.secondaryTextColor]
        )
        
        searchField.becomeFirstResponder()
        
        if(!searchText.isEmpty) {
            searchField.text = searchText
            DispatchQueue.main.async {
                self.highlightResultsForPattern()
                self.selectField(self.searchField)
            }
        }
        
        searchField.returnKeyType = type == .search ? .done : .next
        searchField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        addSubview(searchField)
        
        searchField.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -50.0).isActive = true
        searchField.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        searchField.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        searchField.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 50.0).isActive = true
        
        searchField.delegate = self
        
        closeButtonView = DarkButton(type: .system)
        closeButtonView.addTarget(self, action: #selector(closeButtonAction), for: .touchUpInside)
        closeButtonView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(closeButtonView)
        closeButtonView.imageView!.tintColor = userPreferences.currentTheme.buttonDarkColor
        closeButtonView.imageEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        closeButtonView.setImage(#imageLiteral(resourceName: "close").withRenderingMode(.alwaysTemplate), for: .normal)
        closeButtonView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        closeButtonView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        closeButtonView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        closeButtonView.widthAnchor.constraint(equalToConstant: 40.0).isActive = true
        
        layoutSubviews()
        
        if animated {
            
            let rect = button.convert(button.bounds, to: parent)
            fakeButton.frame = rect
            closeButtonView.alpha = 0.0
            closeButtonView.transform = CGAffineTransform(scaleX: 0.2, y: 0.2).rotated(by: 1.4)
            searchField.alpha = 0.0
            searchField.transform = CGAffineTransform(translationX: 0, y: 30)
            
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .curveEaseInOut, animations: {
                self.fakeButton.frame = CGRect(x: 2, y: 0, width: 40, height: 40)
            }, completion: nil)
            UIView.animate(withDuration: 1.0, delay: 0.3, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.0, options: [], animations: {
                self.closeButtonView.alpha = 1.0
                self.closeButtonView.transform = CGAffineTransform.identity
            }, completion: nil)
            UIView.animate(withDuration: 0.7) {
                self.searchField.alpha = 1.0
                self.searchField.transform = CGAffineTransform.identity
            }
        } else {
            self.fakeButton.frame = CGRect(x: 2, y: 0, width: 40, height: 40)
        }
    }
    
    
    @objc func textFieldDidChange() {
        
        if(step == 0) {
            searchText = searchField.text!
            highlightResultsForPattern()
        }
        
    }
    
    func nextStep() {
        
        if(step != 1 && self.searchField.text!.isEmpty) {
            return
        }
        
        endEditing(true)
        
        if(type == .search) {
            
            UIView.animate(withDuration: 0.3, animations: {
                self.searchField.transform = CGAffineTransform(translationX: 0, y: -40)
                self.searchField.alpha = 0.0
            })
            
            self.searchText = searchField.text ?? ""
            
            searchField.resignFirstResponder()
            
            search()
            
        } else if(step == 0) {
            if(replaceField == nil) {
                replaceField = UITextField()
                replaceField.alpha = 0.0
                replaceField.attributedPlaceholder = NSAttributedString(
                    string: localize("replacewith", .editor),
                    attributes: [.foregroundColor : userPreferences.currentTheme.secondaryTextColor]
                )
                replaceField.returnKeyType = .done
                replaceField.delegate = self
                
                configureTextField(replaceField)
                
                addSubview(replaceField)
                
                replaceField.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -50.0).isActive = true
                replaceField.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
                replaceField.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
                replaceField.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 50.0).isActive = true
                
                replaceField.becomeFirstResponder()
                
                if(!replaceText.isEmpty) {
                    replaceField.text = replaceText
                    DispatchQueue.main.async {
                        self.selectField(self.replaceField)
                    }
                }
            } else {
                replaceField.becomeFirstResponder()
                DispatchQueue.main.async {
                    self.selectField(self.replaceField)
                }
            }
            replaceField.transform = CGAffineTransform(translationX: 0, y: 40)
            
            self.searchText = searchField.text ?? ""
            
            layoutSubviews()
            
            UIView.animate(withDuration: 0.3, animations: {
                self.replaceField.transform = .identity
                self.replaceField.alpha = 1.0
                self.searchField.transform = CGAffineTransform(translationX: 0, y: -40)
                self.searchField.alpha = 0.0
            })
            
            step = 1
        } else {
            
            UIView.animate(withDuration: 0.3, animations: {
                self.replaceField.transform = CGAffineTransform(translationX: 0, y: -40)
                self.replaceField.alpha = 0.0
            })
            
            replaceText = self.replaceField.text!
            replaceField.resignFirstResponder()
            
            search()
        }
        return
    }
}
