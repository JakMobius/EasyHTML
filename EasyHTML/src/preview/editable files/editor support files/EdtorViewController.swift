import UIKit
import WebKit
import Zip
import MessageUI

extension WKWebViewConfiguration {
    func addScript(script: String, scriptHandlerName: String, scriptMessageHandler: WKScriptMessageHandler, injectionTime: WKUserScriptInjectionTime) {
        let userScript = WKUserScript(source: script, injectionTime: injectionTime, forMainFrameOnly: false)
        userContentController.addUserScript(userScript)
        userContentController.add(scriptMessageHandler, name: scriptHandlerName)
    }
}

protocol EditorDelegate: AnyObject {
    func editor(loaded editor: EditorViewController)
    func editor(shouldSaveFileNow editor: EditorViewController) -> Bool
    func editor(saveFile editor: EditorViewController)
    func editor(toggledExpanderView editor: EditorViewController)
    func editor(fallBackToASCII editor: EditorViewController)
    func editor(encodingFor editor: EditorViewController) -> String.Encoding
    func editor(crashed editor: EditorViewController)
    func editor(closed editor: EditorViewController)
}

/// The first of the three editor controllers. Responsible for displaying the editor based on CodeMirror©

class EditorViewController: UIViewController, UIScrollViewDelegate, WKScriptMessageHandler, ColorPickerDelegate, GradientPickerDelegate, UIGestureRecognizerDelegate, FindReplaceDialogDelegate, NotificationHandler, EditorPredictiveTextFieldDelegate, ExpanderViewDelegate, WKUIDelegate {

    // MARK: Internal fields

    private var messageManager: EditorMessageViewManager!

    private var findReplaceDialog: FindReplaceDialogContainerView? = nil
    var webView: SwizzledWebView!

    private(set) var canUndo: Bool = false
    private(set) var canRedo: Bool = false

    private var loadingInfoView: LoadingInfoView! = LoadingInfoView()

    private var rightEditorConstraint: NSLayoutConstraint?
    private var leftEditorConstraint: NSLayoutConstraint?
    private var bottomEditorConstraint: NSLayoutConstraint?
    private var topEditorConstraint: NSLayoutConstraint?

    // MARK: Expander view fields
    var expanderView = ExpanderView()

    private var colorPickerOpened = false
    private var colorPickerInitialColor = "white"

    weak var delegate: EditorDelegate!
    weak var dispatcher: SourceCodeEditorSessionDispatcher!
    var file: FSNode.File!

    private var isExpanderOpened = false

    @objc func dummy() {
    }

    /// Indicates if emmet is actually enabled in this instance of the editor
    var emmetEnabled = false

    /// Indicates is code autocompletion is actually enabled in this instance of the editor
    var codeAutocompletionEnabled = false
    var isReadonly = false

    let emmetKeyBingings: [UIKeyCommand] = [
        KeyCommands.expandAbbreviation,
        KeyCommands.balanceInward,
        KeyCommands.balanceOutward,
        KeyCommands.wrapWithAbbreviation,
        KeyCommands.selectScope,
        KeyCommands.selectNextItem,
        KeyCommands.selectPreviousItem,
        KeyCommands.nextEditPoint,
        KeyCommands.prevEditPoint,
        KeyCommands.reflectCSSValue,
        KeyCommands.solveMathExpression
    ]

    let basicKeyBingings: [UIKeyCommand] = [
//        KeyCommands.undo,
//        KeyCommands.redo,
        KeyCommands.searchInCode,
        KeyCommands.replaceInCode,
        KeyCommands.commentOut,
        KeyCommands.save,
        KeyCommands.insertlineafter,
        KeyCommands.insertlinebefore,
        KeyCommands.selectline,
        KeyCommands.duplicateline,
        KeyCommands.jumptobracket,
        KeyCommands.deleteLineBeforeCursor,
        KeyCommands.goLineStartSmart,
        KeyCommands.fontup,
        KeyCommands.fontdown,
        KeyCommands.goWordLeft,
        KeyCommands.goWordRight,
        KeyCommands.goToDocumentEndCmd,
        KeyCommands.goToDocumentStartCmd,
        KeyCommands.goToDocumentEndCtrl,
        KeyCommands.goToDocumentStartCtrl,
        KeyCommands.goCharLeft,
        KeyCommands.goCharRight,
        KeyCommands.goLineUp,
        KeyCommands.goLineDown,
        KeyCommands.selectWordLeft,
        KeyCommands.selectWordRight
    ]

    override var keyCommands: [UIKeyCommand] {

        var commands: [UIKeyCommand] = []

        if editorLoaded {
            if emmetEnabled {
                commands.append(contentsOf: emmetKeyBingings)
            }
            commands.append(contentsOf: basicKeyBingings)
        }

        return commands
    }

    func executeCommand(_ command: String) {
        webView.evaluateJavaScript("editor.execCommand('\(command)')", completionHandler: nil)
    }

    func updateTheme() {

        let theme = userPreferences.currentTheme.isDark ? "monokai" : "default"
        let color = userPreferences.currentTheme.isDark ? "#272822" : "#ffffff"
        webView?.evaluateJavaScript("""
                                    editor.setOption('theme','\(theme)')
                                    document.body.background="\(color)"
                                    """, completionHandler: nil)
        updateBackground()
    }

    internal func notifyFileMoved() {
        messageManager.newWarning(message: localize("filemoved", .editor)).applyingStyle(style: .warning).present()
    }

    internal func updateFontSize() {
        webView.evaluateJavaScript("document.body.style.fontSize='\(userPreferences.fontSize)px';editor.refresh()", completionHandler: nil)

        expanderView.getButton(typed: .fontup)?.isEnabled = userPreferences.fontSize < 20
        expanderView.getButton(typed: .fontdown)?.isEnabled = userPreferences.fontSize > 10

        Defaults.set(userPreferences.fontSize, forKey: DKey.fontSize)
    }

    // MARK: Expander button callbacks

    final func performUndo() {

        guard canUndo else {
            return
        }

        let undoButton = expanderView.getButton(typed: .undo)
        let redoButton = expanderView.getButton(typed: .redo)

        undoButton?.isEnabled = false
        redoButton?.isEnabled = true

        canUndo = false
        canRedo = true

        webView.evaluateJavaScript("editor.undo();editor.historySize().undo", completionHandler: {
            (result: Any?, error: Error?) -> Void in

            self.canUndo = result as? Double ?? 0 != 0
            undoButton?.isEnabled = self.canUndo
            if self.canUndo {
                self.updateUndoManager()
            }
        })
    }

    final func performRedo() {

        guard canRedo else {
            return
        }

        let undoButton = expanderView.getButton(typed: .undo)
        let redoButton = expanderView.getButton(typed: .redo)

        undoButton?.isEnabled = false
        redoButton?.isEnabled = true

        canRedo = false
        canUndo = true

        webView.evaluateJavaScript("editor.redo();editor.historySize().redo", completionHandler: {
            (result: Any?, error: Error?) -> Void in

            self.canRedo = result as? Double ?? 0 != 0
            redoButton?.isEnabled = self.canRedo
            self.updateUndoManager()
        })
    }

    var lockExpanding = false

    private var ownSearchQuery: String = ""
    private var ownReplaceQuery: String = ""

    private func createFindReplaceDialog(tappedButton button: UIButton, type: FindReplaceDialogContainerView.ButtonActionType, animated: Bool, string: String!) {

        guard !lockExpanding else {
            return
        }

        var animated = animated

        if findReplaceDialog != nil {
            if findReplaceDialog!.type != type {
                findReplaceDialog!.close(animated: false)
                animated = false
            } else {
                if string != nil {
                    findReplaceDialog?.searchText = string
                }
                findReplaceDialog?.focus()
                return
            }
        }
        if !isExpanderOpened {
            delegate?.editor(toggledExpanderView: self)
        }

        if animated {
            UIView.animate(withDuration: 0.5, animations: {
                self.expanderView.scrollView.alpha = 0.0
            }, completion: {
                _ in
                self.expanderView.scrollView.isHidden = true
            })
        } else {
            expanderView.scrollView.isHidden = true
        }

        findReplaceDialog = FindReplaceDialogContainerView(parent: expanderView, type: type, webView: webView)

        findReplaceDialog!.searchText = string ?? ownSearchQuery
        findReplaceDialog!.replaceText = ownReplaceQuery

        findReplaceDialog!.present(tapedButton: button, animated: animated)

        findReplaceDialog!.delegate = self
    }

    func searchInCode(text: String! = nil) {
        guard let button = expanderView.getButton(typed: .search) else {
            return
        }

        createFindReplaceDialog(tappedButton: button, type: .search, animated: isExpanderOpened, string: text)
    }

    func replaceInCode(text: String! = nil) {
        guard let button = expanderView.getButton(typed: .replace) else {
            return
        }

        createFindReplaceDialog(tappedButton: button, type: .replace, animated: isExpanderOpened, string: text)
    }

    @objc func searchInCodeKeyAction() {
        searchInCode()
    }

    @objc func replaceInCodeKeyAction() {
        replaceInCode()
    }

    final func saveFile() {
        expanderView.getButton(typed: .save)?.isEnabled = false

        delegate?.editor(saveFile: self)
    }

    internal func findReplaceDialog(willClose dialog: FindReplaceDialogContainerView, animated: Bool) {
        ownSearchQuery = dialog.searchText
        ownReplaceQuery = dialog.replaceText
        expanderView.scrollView.isHidden = false
        if animated {
            UIView.animate(withDuration: 0.5) {
                self.expanderView.scrollView.alpha = 1.0
            }
        } else {
            expanderView.scrollView.alpha = 1.0
        }
        findReplaceDialog = nil
    }

    internal func findReplaceDialog(_ dialog: FindReplaceDialogContainerView, scrolledTo x: Int, _ y: Int) {
        wkOffset.x = CGFloat(x)
        wkOffset.y = CGFloat(y)
    }

    /// Expands the helper menu
    /// - Returns: A boolean indicating whether the menu was expanded successfully
    internal func expand() -> Bool {

        guard editorLoaded else {
            return false
        }
        guard !lockExpanding else {
            return false
        }

        lockExpanding = true

        isExpanderOpened = !isExpanderOpened

        if isExpanderOpened {
            topEditorConstraint!.constant = 40
            expanderView.isHidden = false
        } else {
            topEditorConstraint!.constant = 0
        }

        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutSubviews()
        }, completion: {
            success in
            self.lockExpanding = false
            if (success && !self.isExpanderOpened) {
                self.expanderView.isHidden = true
            }
        })

        return true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        messageManager.recalculatePositions()

        transitionManager(animation: false)
    }

    let predictiveTextView = EditorPredictiveTextMenu.shared

    private func setupExpanderView() {
        view.addSubview(expanderView)
        expanderView.delegate = self
        expanderView.config = userPreferences.expanderButtonsList
        expanderView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        expanderView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        expanderView.bottomAnchor.constraint(equalTo: webView.topAnchor).isActive = true
        expanderView.layoutButtons()

        NotificationCenter.default.addObserver(self, selector: #selector(updateExpander), name: .TCUpdateExpanderMenu, object: nil)
    }

    @objc func updateExpander() {

        if findReplaceDialog != nil {
            findReplaceDialog!.close(animated: false)
            findReplaceDialog = nil
        }

        expanderView.config = userPreferences.expanderButtonsList
        expanderView.layoutButtons()
    }

    func expanderViewButtonTapped(type: ExpanderButtonItem.ButtonType, repeating: Bool) {
        switch type {
        case .undo:
            performUndo()
        case .redo:
            performRedo()
        case .save:
            guard !repeating else {
                return
            }
            saveFile()
        case .colorpicker:
            guard !repeating else {
                return
            }
            showColorPicker()
        case .gradientpicker:
            guard !repeating else {
                return
            }
            showGradientPicker()
        case .search:
            guard !repeating else {
                return
            }
            searchInCode()
        case .replace:
            guard !repeating else {
                return
            }
            replaceInCode()
        case .fontup:
            if (userPreferences.fontSize < 20) {
                userPreferences.fontSize += 1
                updateFontSize()
            }
        case .fontdown:
            if (userPreferences.fontSize > 10) {
                userPreferences.fontSize -= 1
                updateFontSize()
            }
        case .bracketleft:
            trigger(key: "(", num: "57")
        case .bracketright:
            trigger(key: ")", num: "41")
        case .curvedbracketleft:
            trigger(key: "{", num: "123")
        case .curvedbracketright:
            trigger(key: "}", num: "125")
        case .squarebracketleft:
            trigger(key: "[", num: "91")
        case .squarebracketright:
            trigger(key: "]", num: "93")
        case .greaterthan:
            trigger(key: ">", num: "62")
        case .lessthan:
            trigger(key: "<", num: "60")
        case .quote:
            trigger(key: "\"", num: "222")
        case .goSymbolLeft:
            executeCommand("goCharLeft")
        case .goSymbolRight:
            executeCommand("goCharRight")
        case .tab:
            triggerTab()
        case .indent:
            guard !repeating else {
                return
            }
            executeCommand("indentAuto")
        case .singlequote:
            trigger(key: "'", num: "222")
        case .goToDocumentStart:
            jumpToDocumentStart()
        case .goToDocumentEnd:
            jumpToDocumentEnd()
        case .commentLine:
            smartComment()
        }
    }

    private func trigger(key: String, num: String) {
        webView.evaluateJavaScript("""
                                       var e={
                                       keyCode: \(num),
                                       defaultPrevented: false,
                                       target: editor.display.wrapper,
                                       preventDefault: Function()
                                       }
                                       editor.triggerOnKeyDown(e)
                                       editor.triggerOnKeyPress({
                                       defaultPrevented: false,
                                       key: '\(key)',
                                       keyCode: '\(key)'.charCodeAt(0),
                                       target: editor.display.wrapper,
                                       preventDefault: Function()
                                       })
                                       editor.triggerOnKeyUp(e)
                                   """, completionHandler: nil)
    }

    private func configureWebView() {

        let config = WKWebViewConfiguration()

        let handler = WKScriptMessageHandlerLeakSafeWrapper(delegate: self)

        config.addScript(script: "webkit.messageHandlers.\(WebViewActions.didFinishLoadAction).postMessage(document.URL)", scriptHandlerName: WebViewActions.didFinishLoadAction, scriptMessageHandler: handler, injectionTime: .atDocumentEnd)
        config.userContentController.add(handler, name: WebViewActions.colorAction)
        config.userContentController.add(handler, name: WebViewActions.gradientAction)
        config.userContentController.add(handler, name: WebViewActions.cursorAction)
        config.userContentController.add(handler, name: WebViewActions.inputAction)
        config.userContentController.add(handler, name: WebViewActions.scrollAction)

        webView = SwizzledWebView(frame: CGRect(), configuration: config)
        webView.isHidden = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }

        view.addSubview(webView)

        webView.scrollView.bounces = false
        webView.scrollView.delegate = self
        webView.uiDelegate = self
        webView.scrollView.bouncesZoom = false
        webView.scrollView.maximumZoomScale = 1.1
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.keyboardDisplayRequiresUserAction = false

        webView.subviewWithClassName("WKContentView")!.swizzle()
    }

    private func setupGestureRecognizers() {
        webView.scrollView.bounces = false
//        let pinchGestureRecogniser = UIPinchGestureRecognizer(target: self, action: #selector(pinchGestureAction(_:)))
//        pinchGestureRecogniser.delegate = self
//        let longPressGestureRecogniser = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureAction(_:)))
//        longPressGestureRecogniser.minimumPressDuration = 0.6
//        longPressGestureRecogniser.delegate = self
//        let panGestureRecogniser = UIPanGestureRecognizer(target: self, action: #selector(touchDidMove))
//        panGestureRecogniser.delegate = self
//        panGestureRecogniser.maximumNumberOfTouches = 1
//        panGestureRecogniser.minimumNumberOfTouches = 1
//
//        let touchGestureRecogniser = InstantTapGestureRecognizer(target: self, action: #selector(touchStart))
//        touchGestureRecogniser.delegate = self
//
//        webView.scrollView.addGestureRecognizer(pinchGestureRecogniser)
//        webView.scrollView.addGestureRecognizer(longPressGestureRecogniser)
//        webView.scrollView.addGestureRecognizer(touchGestureRecogniser)
//        webView.scrollView.addGestureRecognizer(panGestureRecogniser)
//
//        if(isReadonly) {
//            let touchGesture = UITapGestureRecognizer(target: self, action: #selector(showReadonlyWarning))
//            touchGesture.delegate = self
//            webView.scrollView.addGestureRecognizer(touchGesture)
//        }
    }

    private func setupWebViewConstraints() {
        leftEditorConstraint = webView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        rightEditorConstraint = webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        bottomEditorConstraint = webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 30.0)
        topEditorConstraint = webView.topAnchor.constraint(equalTo: view.topAnchor)

        leftEditorConstraint!.isActive = true
        rightEditorConstraint!.isActive = true
        bottomEditorConstraint!.isActive = true
        topEditorConstraint!.isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure WKWebView, load the page, boot up the editor, show the loading screen display, disable scrolling

        messageManager = EditorMessageViewManager(parent: self)

        edgesForExtendedLayout = []

        view.isOpaque = true

        updateBackground()
        configureWebView()
        setupGestureRecognizers()
        setupWebViewConstraints()
        loadBasicEditor()
        setupExpanderView()

        transitionManager(animation: false)

        setupLanguageChangedNotificationHandling()
        setupKeyboardWillShowNotificationHandling()
        setupKeyboardWillHideNotificationHandling()
        setupKeyboardDidHideNotificationHandling()
        setupKeyboardWillChangeFrameNotificationHandling()
        setupThemeChangedNotificationHandling()
        setupRotationNotificationHandling()

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override func didMove(toParent parent: UIViewController?) {
        tabBarItem?.image = UIImage(named: "editor")
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    func languageChanged() {
        handleCursor(type: nil, string: lastString, completions: nil, userInfo: nil)
    }

    //MARK: Color picker and gradient picket event handlers

    private var colorPickerBusy = false
    private var colorPickerNeedsUpdate = false

    final func colorPicker(colorDidChange sender: ColorPicker) {
        guard colorPickerOpened else {
            return
        }
        guard !isReadonly else {
            return
        }

        if colorPickerBusy {
            colorPickerNeedsUpdate = true
            return
        }

        func sendColor() {
            colorPickerNeedsUpdate = false
            colorPickerBusy = true
            webView.evaluateJavaScript("window.colorpickerCallback('\(sender.colorPreviewText.text ?? "transparent")')", completionHandler: {
                _, _ in
                self.colorPickerBusy = false
                if self.colorPickerNeedsUpdate {
                    sendColor()
                }
            })
        }

        sendColor()
    }

    final func colorPicker(colorPickerDidCancel sender: ColorPicker) {
        if (colorPickerOpened) {
            if (!isReadonly) {
                webView.evaluateJavaScript("window.colorpickerCallback(\(colorPickerInitialColor))", completionHandler: nil)
            }

            colorPickerOpened = false
        }
    }

    private func pickerAction(message: String, item: String) {
        let action = TCAlertController.getNew()

        action.applyDefaultTheme()

        func copy(_ button: UIButton, _ action: TCAlertController) {
            UIPasteboard.general.string = item
        }

        func paste(_ button: UIButton, _ action: TCAlertController) {
            webView?.evaluateJavaScript("editor.getDoc().replaceRange(\"\(item)\",editor.getDoc().getCursor())", completionHandler: nil)
        }

        action.contentViewHeight = 10
        action.minimumButtonsForVerticalLayout = 0
        action.constructView()
        action.header.numberOfLines = 3
        action.makeCloseableByTapOutside()
        action.headerText = message
        action.header.transform = CGAffineTransform(translationX: 0, y: 10)
        action.contentView.backgroundColor = UIColor.clear
        action.header.font = UIFont.systemFont(ofSize: 18)

        action.addAction(action: TCAlertAction(text: localize("copy"), action: copy, shouldCloseAlert: true))
        action.addAction(action: TCAlertAction(text: localize("pasteincode"), action: paste, shouldCloseAlert: true))
        action.buttons[1].isEnabled = !isReadonly

        action.animation = TCAnimation(animations: [.scale(0.8, 0.8), .opacity], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.6)

        view.window!.addSubview(action.view)
    }

    final func colorPicker(colorPickerDidConfirm sender: ColorPicker) {
        if (colorPickerOpened) {
            if (!isReadonly) {
                webView.evaluateJavaScript("window.colorpickerCallback('\(sender.colorPreviewText.text ?? "transparent")')", completionHandler: nil)
            }

            colorPickerOpened = false
        } else {
            pickerAction(message: localize("colorquestion"), item: sender.colorPreviewText.text ?? "white")
        }
    }

    final func gradientPicker(didChange sender: GradientPicker) {
        guard colorPickerOpened else {
            return
        }
        guard !isReadonly else {
            return
        }

        if colorPickerBusy {
            colorPickerNeedsUpdate = true
            return
        }

        func sendColor() {
            colorPickerNeedsUpdate = false
            colorPickerBusy = true
            webView.evaluateJavaScript("window.colorpickerCallback('\(sender.getCode().replacingOccurrences(of: "\n", with: "\\\n").replacingOccurrences(of: "\'", with: "\\\'"))')", completionHandler: {
                _, _ in
                self.colorPickerBusy = false
                if self.colorPickerNeedsUpdate {
                    sendColor()
                }
            })
        }
    }

    final func gradientPicker(didConfirm sender: GradientPicker) {
        if (colorPickerOpened) {
            if (!isReadonly) {
                webView.evaluateJavaScript("window.colorpickerCallback('\(sender.getCode().replacingOccurrences(of: "\n", with: "\\\n").replacingOccurrences(of: "\'", with: "\\\'"))')')", completionHandler: nil)
            }
            colorPickerOpened = false
        } else {
            pickerAction(message: localize("gradquestion"), item: sender.getCode())
        }
    }

    @objc func applicationDidBecomeActive() {
        //self.
        showKeyboard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if (webView != nil) {
            setWebViewBottomInset(0)

            webView.setNeedsLayout()
            webView.layoutIfNeeded()
        }
    }

    // MARK: WKWebView event handling. Opens color picker and gradient picker, handles text input and editor loading.

    final func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch (message.name) {

        case WebViewActions.scrollAction:
            guard let r = message.body as? Array<Int> else {
                return
            }

            let offsetX = r[0]
            let offsetY = r[1]

            let offset = CGPoint(x: offsetX, y: offsetY)
            handleJavaScriptScrollAction(offset: offset)

        case WebViewActions.didFinishLoadAction:
            webViewDidFinishLoad()
        case WebViewActions.colorAction:

            if (!isReadonly && message.body is Array<Any> && (message.body as! Array<Any>).count == 5) {

                let array = message.body as! Array<Any>
                if (array[0] is Array<Any>) {

                    let x = (array[1] as? Double ?? -1) * Double(webView.scrollView.zoomScale) + Double(webView.frame.minX)
                    let y = (array[2] as? Double ?? -1) * Double(webView.scrollView.zoomScale) + Double(webView.frame.minY)
                    guard let w = array[3] as? Double else {
                        return
                    }
                    guard let h = array[4] as? Double else {
                        return
                    }

                    guard   !x.isNaN &&
                                    x >= 0 &&
                                    !y.isNaN &&
                                    y >= 0 &&
                                    !w.isNaN &&
                                    w > 0 &&
                                    !h.isNaN &&
                                    h > 0

                    else {
                        print("Wrong color data received!"); return
                    }

                    let colors = array[0] as! Array<Any>
                    let red = CGFloat(colors[0] as! Double / 255)
                    let green = CGFloat(colors[1] as! Double / 255)
                    let blue = CGFloat(colors[2] as! Double / 255)
                    let alpha = CGFloat(colors[3] as! Double)
                    colorPickerInitialColor = colors[4] as! String
                    let c = UIColor(red: red, green: green, blue: blue, alpha: alpha);
                    colorPickerOpened = true

                    var frame = CGRect(x: x, y: y, width: w, height: h)
                    frame = view.convert(frame, to: view.window!.rootViewController!.view)

                    webView.resignFirstResponder()

                    ColorPicker.present(from: view.window!.rootViewController!, origin: UIView(frame: frame))
                            .setColorPickerInitialColor(c)
                            .setDelegate(delegate: self)

                    deceleratingVelocity = nil
                }
            }

            break;
        case WebViewActions.gradientAction:
            if (isReadonly) {
                return
            }
            let array = message.body as! Array<Any>
            if (array[0] is Array<Any>) {

                let data = array[0] as! Array<Any>
                let x = (array[1] as? Double ?? 0) * Double(webView.scrollView.zoomScale) + Double(webView.frame.minX)
                let y = (array[2] as? Double ?? 0) * Double(webView.scrollView.zoomScale) + Double(webView.frame.minY)
                let w = array[3] as? Double ?? 0
                let h = array[4] as? Double ?? 0

                guard w > 0 && h > 0 else {
                    print("Wrong gradient data received!"); return
                }

                let type = data[0] as? Int ?? -1
                if (type == -1) {
                    return;
                }
                var colors = [UIColor]()
                var positions = [NSNumber]()
                if (type == 1 || type == 0) {
                    let prefix = data[1] as! String
                    for i in 3..<data.count {
                        guard let d = (data[i] as? Array<Any>) else {
                            continue
                        }
                        let r = d[0] as! CGFloat
                        let g = d[1] as! CGFloat
                        let b = d[2] as! CGFloat
                        let a = d[3] as! CGFloat
                        colors.append(UIColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a))
                        positions.append(NSNumber(value: round(d[4] as! Double / 10) / 10))
                    }
                    var gradient: TCGradient
                    var options = ""
                    if (type == 0) {
                        let degree = data[2] as! CGFloat
                        gradient = TCGradient(colors: colors, location: positions, startPoint: CGPoint.zero, endPoint: CGPoint(x: 1, y: 1), isRadial: false, angle: Float(degree))
                    } else {
                        options = data[2] as! String
                        gradient = TCGradient(colors: colors, location: positions, startPoint: CGPoint.zero, endPoint: CGPoint(x: 1, y: 1), isRadial: true, angle: 0)
                    }

                    let controller = PrimarySplitViewController.instance(for: view)!

                    var frame = CGRect(x: x, y: y, width: w, height: h)
                    frame = view.convert(frame, to: controller.view)

                    webView.resignFirstResponder()

                    GradientPicker.present(from: controller, origin: UIView(frame: frame))
                            .setPrefix(prefix)
                            .setGradient(gradient)
                            .setGradientUnsupportedOptions(options)
                            .setGradientPickerDelegate(self)
                    colorPickerOpened = true

                    deceleratingVelocity = nil

                } else {
                    print("Wrong gradient data received!")
                }
            }
            break;
        case WebViewActions.inputAction:

            guard let r = message.body as? Array<Any> else {
                return
            }
            guard
                    let undos = r[0] as? Int,
                    let redos = r[1] as? Int
            else {
                return
            }

            let origin = r[2] as? String ?? ""

            handleInput(undos: undos, redos: redos, origin: origin)

        case WebViewActions.cursorAction:

            guard let r = message.body as? Array<Any> else {
                return
            }

            if let completions = parseCompletions(data: r) {
                handleCursor(
                        type: r[0] as? String,
                        string: r[1] as? String,
                        completions: completions.completions,
                        userInfo: completions.userInfo
                )
            } else {
                handleCursor(type: r[0] as? String, string: r[1] as? String, completions: nil, userInfo: nil)
            }


        default:break;
        }
    }

    private func parseCompletions(data: [Any]) -> (completions: [PredictiveTextItem], userInfo: NSMutableDictionary)? {

        if let completionData = data[2] as? Array<Any> {

            let userInfo = NSMutableDictionary()

            let from = data[3]
            let to = data[4]

            userInfo[fromKey] = from
            userInfo[toKey] = to

            var completions = [PredictiveTextItem]()

            for completionItem in completionData {
                if let textCompletion = completionItem as? String {
                    var item = PredictiveTextItem(title: textCompletion)
                    item.userInfo = userInfo
                    completions.append(item)
                } else if let complexCompletion = completionItem as? [AnyHashable: String] {
                    guard let title = complexCompletion[titleKey] else {
                        continue
                    }

                    let currentUserInfo = NSMutableDictionary()

                    currentUserInfo[completionLastKey] = complexCompletion[completionLastKey]
                    currentUserInfo[completionFirstKey] = complexCompletion[completionFirstKey]
                    currentUserInfo[fromKey] = complexCompletion[fromKey] ?? from
                    currentUserInfo[toKey] = complexCompletion[toKey] ?? to
                    currentUserInfo[customScriptKey] = complexCompletion[customScriptKey]

                    let item = PredictiveTextItem(title: title, userInfo: currentUserInfo)

                    completions.append(item)
                }
            }

            return (completions: completions, userInfo: userInfo)
        }

        return nil
    }

    private let fromKey = "0"
    private let toKey = "1"
    private let sourceWordLengthKey = "2"
    private let completionFirstKey = "3"
    private let completionLastKey = "4"
    private let titleKey = "5"
    private let customScriptKey = "6"

    final func tappedSuggestion(_ suggestion: PredictiveTextItem) {

        if let from = suggestion.userInfo?[fromKey] as? String,
           let to = suggestion.userInfo?[toKey] as? String {

            if var complexSuggestionContent = suggestion.userInfo?[completionFirstKey] as? String {

                complexSuggestionContent = EditorViewController.getEscapedJavaScriptString(complexSuggestionContent)

                let complexSuggestionLastContent = suggestion.userInfo![completionLastKey] as? String

                var script = """
                             editor.operation(function(){var f=eval(\(from));editor.replaceRange('\(complexSuggestionContent)',f,eval(\(to)));
                             """

                if var addition = complexSuggestionLastContent {
                    addition = EditorViewController.getEscapedJavaScriptString(addition)
                    script += """
                              var c = editor.getCursor(),t='\(addition)'
                              editor.replaceRange(t,c)
                              editor.setCursor(c)
                              var d=t.split("\\n").length+c.line-1;
                              """
                } else {
                    script += """
                              var d=editor.getCursor().line;
                              """
                }


                if let additionalScript = suggestion.userInfo![customScriptKey] as? String {
                    script += """
                              \(additionalScript)
                              editor.setCursor(editor.getCursor())
                              })
                              """
                } else {
                    script += """
                              for(var l=f.line;l<=d;l++)editor.indentLine(l,'smart',true);
                              editor.setCursor(editor.getCursor())
                              })
                              """
                }

                webView.evaluateJavaScript(script, completionHandler: nil)
                return
            }

            let string = EditorViewController.getEscapedJavaScriptString(suggestion.title)

            webView.evaluateJavaScript("editor.replaceRange('\(string)',eval(\(from)),eval(\(to)));editor.setCursor(editor.getCursor())")
        } else if let sourceWordLength = suggestion.userInfo?[sourceWordLengthKey] as? Int {

            let string = EditorViewController.getEscapedJavaScriptString(suggestion.title)

            webView.evaluateJavaScript("""
                                               (function(){
                                               var c=editor.getCursor(),
                                                   f={line:c.line,ch:c.ch-\(sourceWordLength)}
                                               editor.replaceRange('\(string) ',f,c)
                                               })()
                                       """)
        }

    }

    private func handleJavaScriptScrollAction(offset: CGPoint) {
        if abs(offset.x - offsetAfterLastCursorUpdate.x) > cursorUpdateLimit ||
                   abs(offset.y - offsetAfterLastCursorUpdate.y) > cursorUpdateLimit {
            offsetAfterLastCursorUpdate = offset
            webView.evaluateJavaScript("var s=window.getSelection(),c=s.rangeCount,r=[];while(c--)r.push(s.getRangeAt(c));s.removeAllRanges();r.forEach(function(a){s.addRange(a)})}", completionHandler: nil)
        }

        wkOffset = offset
    }

    var lastString: String?

    private func handleCursor(type: String?, string: String?, completions: [PredictiveTextItem]?, userInfo: NSMutableDictionary?) {

        var userInfo = userInfo
        if userInfo == nil {
            userInfo = NSMutableDictionary()
        }

        var completions = completions ?? []

        if type == "string" || type == "comment", let string = string {
            lastString = string

            if let firstResponder = webView.firstResponder,
               let language = firstResponder.textInputMode?.primaryLanguage,
               language != "emoji" {

                let suggestions = UITextChecker.getSuggestions(for: string, language: language)

                if let items = suggestions.suggestions {
                    for item in items {
                        completions.append(.init(title: item, userInfo: userInfo))
                    }
                }

                userInfo![sourceWordLengthKey] = suggestions.sourceWord?.count
            }
        } else {
            lastString = nil
        }

        if !completions.isEmpty {
            predictiveTextView.suggest(items: completions)
        } else {
            if !predictiveTextView.predictiveTextField.isEmpty {
                predictiveTextView.suggest(items: [])
            }
        }
    }

    private func rebuildUndoStack(undoManager: UndoManager) {

        DispatchQueue.main.async {
            undoManager.groupsByEvent = false

            undoManager.removeAllActions()

            if self.canUndo {
                undoManager.beginUndoGrouping()
                undoManager.registerUndo(withTarget: self) { (me) in
                    me.performUndo()
                }
                undoManager.endUndoGrouping()
            }

            if self.canRedo {
                undoManager.beginUndoGrouping()
                undoManager.registerUndo(withTarget: self) { (me) in
                    undoManager.registerUndo(withTarget: self) { (me) in
                        me.performRedo()
                    }
                }
                undoManager.endUndoGrouping()
                undoManager.undo()
            }

            undoManager.groupsByEvent = true
        }

    }

    private func updateUndoManager() {

        guard let firstResponder = webView.firstResponder else {
            return
        }
        guard let undoManager = firstResponder.undoManager else {
            return
        }

        if undoManager.canRedo != canRedo || undoManager.canUndo != canUndo {
            rebuildUndoStack(undoManager: undoManager)
        }
    }

    private func handleInput(undos: Int, redos: Int, origin: String) {
        expanderView.getButton(typed: .undo)?.isEnabled = undos > 0
        expanderView.getButton(typed: .redo)?.isEnabled = redos > 0

        deceleratingVelocity = nil

        if (origin != "+replace") {
            findReplaceDialog?.updateSearchResults()
        }

        canUndo = true

        if delegate == nil || delegate!.editor(shouldSaveFileNow: self) {
            expanderView.getButton(typed: .save)?.isEnabled = true
        }

        userPreferences.statistics.symbolsWrittenTotal += 1

        updateUndoManager()
    }

    // MARK: Methods for processing and uploading a file to the editor

    @objc internal func loadBasicEditor() {

        loadingInfoView.infoLabel.text = localize("loadingstep_booting", .editor)
        loadingInfoView.fade()

        view.addSubview(loadingInfoView)
        view.bringSubviewToFront(loadingInfoView)

        messageManager.reset()
        webView.loadHTMLString(readBundleFile(name: "editor", ext: "html")!, baseURL: nil)
    }

    static func getEscapedJavaScriptString(_ text: String, progress callback: ((Double) -> ())? = nil) -> String {
        var ntext = ""
        var previousWasR = false

        let scalars = text.unicodeScalars
        let count = scalars.count
        let dblCount = Double(count)
        let percent = count / 100

        var iterator = scalars.makeIterator()
        var i: Double = 0, k = 0

        while let scalar = iterator.next() {

            i += 1
            k += 1

            if k >= percent && callback != nil {
                k = 0
                callback!(i / dblCount)
            }


            let value = scalar.value

            if value == 34 {
                "\\\"".write(to: &ntext)
                previousWasR = false
                continue
            }
            if value == 10 {
                if !previousWasR {
                    "\\n".write(to: &ntext)
                } else {
                    previousWasR = false
                }
                continue
            }
            if value == 13 {
                "\\n".write(to: &ntext)
                previousWasR = true
                continue
            }
            if value == 92 {
                "\\\\".write(to: &ntext)
                previousWasR = false
                continue
            }
            if value == 8233 {
                "\\u{2029}".write(to: &ntext)
                previousWasR = false
                continue
            }
            if value == 8232 {
                "\\u{2028}".write(to: &ntext)
                previousWasR = false
                continue
            }

            scalar.write(to: &ntext)
            previousWasR = false
        }

        return ntext
    }

    private var fileReadingRequest: CancellableRequest! = nil

    final func stopFileReadingRequest() {
        fileReadingRequest?.cancel()
    }

    private func getFileContents(completion: ((Data?, Error?) -> ())?, progress: ((Progress) -> ())? = nil) {

        if fileReadingRequest != nil {
            print("getFileContents(completion:progress:) called twice!")
            fileReadingRequest.cancel()
        }

        fileReadingRequest = dispatcher.ioManager.readFileAt(url: file.url, completion: {
            data, error in
            //print("iomanager called back!")
            fileReadingRequest = nil
            completion?(data, error)
        }, progress: {
            prog in
            progress?(prog)
        })
    }

    private var highlightingScheme: SyntaxHighlightScheme!

    private func getEditorInitializationScript(data: Data, progress: ((Double) -> ())? = nil, completion: @escaping (String) -> ()) {
        guard delegate != nil else {
            return
        }

        DispatchQueue.global().async {
            guard self.delegate != nil else {
                return
            }

            let encoding = self.delegate.editor(encodingFor: self)
            var text = String(data: data, encoding: encoding)

            if (text == nil) {
                let newEncoding = String.Encoding.ascii

                let message = localize("encodingerror", .editor)
                        .replacingOccurrences(of: "{1}", with: encoding.getDescription())
                        .replacingOccurrences(of: "{2}", with: newEncoding.getDescription())

                DispatchQueue.main.async {
                    self.messageManager.newWarning(message: message).applyingStyle(style: .warning).present()
                }

                self.delegate.editor(fallBackToASCII: self)

                text = String(data: data, encoding: newEncoding)
            }

            text = EditorViewController.getEscapedJavaScriptString(text!, progress: {
                prog in
                progress?(prog)
            })

            var mime: String

            let ext = self.file.url.pathExtension

            if (userPreferences.emmetEnabled) {
                self.emmetEnabled = true
                let emmetSupportedExtensions = ["html", "htm", "css"]
                self.emmetEnabled = emmetSupportedExtensions.contains(ext)
            } else {
                self.emmetEnabled = false
            }

            var styles = ""
            var scripts = self.emmetEnabled ? readBundleFile(name: "emmet", ext: "js")! : ""

            if userPreferences.syntaxHighlightingEnabled,
               let language = userPreferences.syntaxHighlightingConfiguration.first(where: { $0.ext == ext }) {

                self.highlightingScheme = language

                if (userPreferences.codeAutocompletionEnabled) {
                    let autocompletionSupportedModes = ["js", "xml", "html", "css", "sql"]
                    let mode = self.highlightingScheme.mode

                    self.codeAutocompletionEnabled = false

                    for file in mode.configurationFiles {
                        if autocompletionSupportedModes.contains(file) {
                            self.codeAutocompletionEnabled = true
                            break
                        }
                    }

                } else {
                    self.codeAutocompletionEnabled = false
                }

                mime = language.mode.cmMimeType

                for file in language.mode.configurationFiles {
                    if let script = readBundleFile(name: "c.\(file)", ext: "js") {
                        scripts += script
                    }
                    // else {
                    //    print("[EasyHTML] [EditorViewController] -getEditorInitializationScript: Could not find script file for language \(language)")
                    //}

                    if self.codeAutocompletionEnabled, let autoCompletionScript = readBundleFile(name: "ac.\(file)", ext: "js") {
                        scripts += autoCompletionScript
                    }
                }
            } else {
                mime = "text/plain"
            }

            var command = """
                          document.body.style.fontSize='\(userPreferences.fontSize)px';
                          var editor,c=document.getElementById("c");c.value="\(text!)";
                          editor=CodeMirror.fromTextArea(c,{
                          """

            var usedFilenames = [String]()

            userPreferences.enabledPlugins.forEach {
                plugin in
                command += plugin + ":"
                let data = UserPreferences.plugins[plugin]!

                for i in 0...data.count - 2 {
                    let filename = data[i]
                    if (!filename.isEmpty && !usedFilenames.contains(filename)) {
                        if let js = readBundleFile(name: filename, ext: "js") {
                            scripts += js
                        }
                        // else {
                        // print("[EasyHTML] [EditorViewController] -getEditorInitializationScript: Could not find script file for plugin \(plugin)")
                        // }
                        if let css = readBundleFile(name: filename, ext: "css") {
                            styles += css
                        }
                        // else {
                        //    print("[EasyHTML] [EditorViewController] -getEditorInitializationScript: Could not find css file for plugin \(plugin)")
                        //}

                        usedFilenames.append(filename)
                    }
                }
                command += data.last! + ","
            }

            command += """
                       mode:{name:"\(mime)",globalVars:\(userPreferences.codeAutocompletionEnabled)},
                       theme:"\((userPreferences.currentTheme.isDark ? "monokai" : "default"))",
                       gutters:["CodeMirror-linenumbers","CodeMirror-foldgutter"],
                       readOnly:\(self.isReadonly)
                       })
                       var scrollDiv=document.querySelector(".CodeMirror-scroll"),lockEvents=false,oldx=0,oldy=0;
                       """

            if self.emmetEnabled {
                command += "emmetCodeMirror(editor);"
            }

            if self.codeAutocompletionEnabled {
                command += """
                           function cursorActivity(){
                           if(lockEvents) return
                           var c=editor.getCursor(),
                           t=editor.getTokenAt(c),
                           h=editor.historySize(),
                           f=JSON.stringify,
                           k1=[],
                           k2=null,
                           k3=null,
                           i=['string','def','comment','number'],
                           v="";
                           if(c.ch<t.end){v=t.string.substr(0,c.ch-t.start)}else{v=t.string};
                           if(i.indexOf(t.type)==-1){
                           var u=editor.getHelper(c,'hint');
                           if(u)u=u(editor);
                           if(u){
                           k1=u.list
                           k2=f(u.from)
                           k3=f(u.to)
                           }
                           }
                           webkit.messageHandlers.\(WebViewActions.cursorAction).postMessage([t.type,v,k1,k2,k3])
                           };
                           """
            } else {
                command += """
                           function cursorActivity(){
                           debugger
                           if(lockEvents) return
                           var c=editor.getCursor(),
                           h=editor.historySize()
                           webkit.messageHandlers.\(WebViewActions.cursorAction).postMessage([null,"",[],null,null])
                           };
                           """
            }

            if (styles != "") {
                scripts += """
                           (function(){
                           var k=document.createElement("style");
                           k.innerHTML="\(styles.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\\n"))";
                           document.head.appendChild(k)
                           })();
                           """
            }

            if userPreferences.currentTheme.isDark {
                scripts += "document.body.style.background='#272822';"
            }

            command += """
                           editor.on("change", function(a,b) {
                           if(lockEvents) return
                           var h=editor.historySize()
                           webkit.messageHandlers.\(WebViewActions.inputAction).postMessage([h.undo,h.redo,b.origin])
                           })
                           editor.on("cursorActivity",cursorActivity)
                           editor.on("scroll", function() {
                           var m=scrollDiv,x=m.scrollLeft,y=m.scrollTop
                           if(lockEvents||(x==oldx&&y==oldy))return
                           webkit.messageHandlers.\(WebViewActions.scrollAction).postMessage([x,y])
                           oldx=x;oldy=y;
                           })
                           !function(){
                           var j=editor.state.keyMaps,x
                           for(var i=0,l=j.length;i<l;i++)if(j[i].name=="autoCloseTags")x=j[i]
                           editor._closetag = function() {
                           if(x&&x["'>'"](editor))editor.replaceRange(">",editor.getCursor(),editor.getCursor())
                           }
                           }()

                       """

            completion(scripts + command)
        }
    }

    private static var diskSpaceMessageShownDate: Date! = nil
    private(set) var editorLoaded = false
    internal var initializationScript: String! = nil

    func webViewDidFinishLoad() {
        //print("webViewDidFinishLoad")
        guard delegate != nil else {
            return
        }

        if let freeSize = UIDevice.current.systemFreeSize {
            if (freeSize < Int64(314572800)) { // 300 MB

                let date = Date()

                if EditorViewController.diskSpaceMessageShownDate == nil || date.timeIntervalSince(EditorViewController.diskSpaceMessageShownDate) > 3600 {
                    let localizedSize = getLocalizedFileSize(bytes: freeSize, fraction: 1, shouldCheckAdditionalCases: false)

                    let message = localize("lowdiskspace", .editor).replacingOccurrences(of: "#", with: localizedSize)

                    messageManager.newWarning(message: message)
                            .withAutoClosingEnabled(false)
                            .present()

                    EditorViewController.diskSpaceMessageShownDate = date
                }
            }
        }

        NotificationCenter.default.removeObserver(webView!)

        DispatchQueue(label: "easyhtml.editor.loadingqueue").async {

            /// A function that downloads a file from the network or disk using the specified `IOManager'
            /// After loading, the `getInitScript` method will be called
            func downloadFile() {
                let localizedString = localize("loadingstep_downloading", .editor)

                DispatchQueue.main.sync {
                    self.loadingInfoView.infoLabel.text = localizedString.replacingOccurrences(of: "#", with: "0")
                }

                self.getFileContents(completion: { (data, error) in
                    if let data = data {
                        getInitScript(data: data)
                    } else {
                        DispatchQueue.main.async {
                            let message = error?.localizedDescription ?? localize("downloaderror", .editor)

                            self.messageManager.newWarning(message: localize("downloadknownerror") + "\n" + message)
                                    .applyingStyle(style: .error)
                                    .withCloseable(false)
                                    .withButton(EditorWarning.Button(title: localize("tryagain"), target: self, action: #selector(self.loadBasicEditor)))
                                    .present()

                            //self.loadingSpinner.stopAnimating()
                            //self.loadingDescriptionLabel.isHidden = true

                            self.loadingInfoView.hide()
                        }
                    }
                }, progress: {
                    prog in
                    DispatchQueue.main.async {
                        self.loadingInfoView.infoLabel.text = localizedString.replacingOccurrences(of: "#", with: String(Int(prog.fractionCompleted * 100)))
                    }
                })
            }

            /// Get JS script, which will be loaded into `WKWebView`.
            /// - parameter data: File contents
            func getInitScript(data: Data) {
                let localizedString = localize("loadingstep_processingfile", .editor)

                self.getEditorInitalizationScript(data: data, progress: {
                    prog in
                    DispatchQueue.main.async {
                        self.loadingInfoView.infoLabel.text = localizedString.replacingOccurrences(of: "#", with: String(Int(prog * 100)))
                    }
                }, completion: {
                    script in
                    self.initializationScript = script
                    DispatchQueue.main.async {
                        loadScript(script: script)
                    }
                });
            }

            /**
                Running the initialization script in a `WKWebView`
             - note: Call only from `DispatchQueue.main`
             - parameter script: Script text from `getInitScript(data:)`
             */

            func loadScript(script: String) {

                // Ensure editor is still alive
                guard self.delegate != nil else {
                    return
                }
                self.loadingInfoView.infoLabel.text = localize("loadingstep_loadingfile", .editor)

                self.webView?.evaluateJavaScript(script) {
                    (result: Any?, error: Error?) -> Void in

                    guard self.delegate != nil else {
                        return
                    }

                    if (error != nil) {
                        self.javaScriptError = error
                        print(error!)
                        self.editorErrorOccurred()
                        return
                    }

                    if let scrollPosition = self.file.getScrollPositionPoint() {
                        self.scrollBy(x: scrollPosition.x, y: scrollPosition.y)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        self.webView.isHidden = false
                    })

                    self.editorLoaded = true
                    self.initializationScript = nil
                    self.updateBackground()

                    UIView.animate(withDuration: 0.2, delay: 0.1, options: .curveEaseInOut, animations: {
                        self.loadingInfoView.alpha = 0.0
                    }, completion: { (_) in
                        guard self.delegate != nil else {
                            return
                        }
                        self.loadingInfoView.removeFromSuperview()
                        self.loadingInfoView = nil

                        self.delegate.editor(loaded: self)
                    })
                }
            }

            downloadFile()
        }
    }

    // MARK: Editor error handling

    /// Called if editor failed to boot
    private func editorErrorOccurred() {
        guard delegate != nil else {
            return
        }

        messageManager.newWarning(message: localize("editorerror", .editor))
                .applyingStyle(style: .error)
                .withCloseable(false)
                .withButton(EditorWarning.Button(title: localize("send"), target: self, action: #selector(sendErrorReport(_:))))
                .withButton(EditorWarning.Button(title: localize("cancel"), target: self, action: #selector(closeEditor)))
                .present()

        webView.removeFromSuperview()

        UIView.animate(withDuration: 0.2, delay: 0.1, options: .curveEaseInOut, animations: {

            self.loadingInfoView.alpha = 0.0

            self.tabBarController?.tabBar.alpha = 0.0
            self.expanderView.isHidden = true
            self.delegate.editor(crashed: self)
        }, completion: { (_) in

            self.loadingInfoView.removeFromSuperview()
            self.loadingInfoView = nil

            self.tabBarController?.tabBar.isHidden = true
        })
    }

    @objc func closeEditor() {
        //parentController.editor.closeTab()
        delegate!.editor(closed: self)
    }

    var javaScriptError: Error?

    /// Generates error report and opens e-mail client window
    @objc func sendErrorReport(_ sender: UIButton) {
        sender.setTitle("Generating report...", for: .normal)
        sender.isEnabled = false

        if let warningView = sender.superview as? EditorWarning {
            if (warningView.buttons.count == 2) {
                warningView.uiButtons.last?.removeFromSuperview()
                warningView.uiButtons.removeLast()
                warningView.buttons.removeLast()

                UIView.animate(withDuration: 0.4) {
                    warningView.recalculateButtons()
                }
            }
        }

        DispatchQueue.global().async {
            let formatter = DateFormatter()
            formatter.timeStyle = .long
            formatter.dateStyle = .long
            let errorDescription = self.javaScriptError == nil ? "None. That is strange..." : "\(self.javaScriptError!)"
            var report = """
                         <!--
                             EasyHTML Editor error report

                             Device type: \(UIDevice.current.localizedModel)
                             Device id: \(UIDevice.current.identifierForVendor?.uuidString ?? "Not specified")
                             Named as: \(UIDevice.current.name)
                             System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
                             EasyHTML version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""),
                             Current date and time: \(formatter.string(from: Date())),
                             JavaScript error: \(errorDescription),
                             Application configuration: \(Defaults.defaults.dictionaryRepresentation())

                             Editor script is below:

                         -->

                         """

            report += readBundleFile(name: "editor", ext: "html")!
            report += "<script>"
            report += self.initializationScript ?? "/* Editor script is nil. This is something really strange. */"
            report += "</script>"

            self.initializationScript = nil

            let errorFile = applicationPath + "/error report/report.html"
            let errorPath = URL(fileURLWithPath: errorFile)
            let zipFilePath = errorPath.appendingPathExtension("zip")

            try? FileManager.default.removeItem(at: zipFilePath)


            try? FileManager.default.createDirectory(atPath: applicationPath + "/error report", withIntermediateDirectories: false, attributes: nil)
            try? report.write(toFile: errorFile, atomically: false, encoding: .utf8)

            do {
                var isCompleted = false
                try Zip.zipFiles(paths: [errorPath], zipFilePath: zipFilePath, password: nil, compression: .bestCompression, progress: { (progress) in

                    try? FileManager.default.removeItem(atPath: errorFile)

                    if (isCompleted) {
                        return
                    }
                    if (progress == 1.0) {
                        isCompleted = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            sender.setTitle("Please wait...", for: .normal)
                            if (!ErrorReporter().reportFile(fileURL: zipFilePath, text: "<h5 style='color: #111'>My EasyHTML Editor ran into a problem</h5>", subject: "EasyHTML Editor Error", mime: "application/zip", fileName: "EasyHTML Editor Error Report.zip", parent: PrimarySplitViewController.instance(for: self.view)!, completion: {
                                self.closeEditor()
                            })) {
                                sender.setTitle("Please, set up your mail application and try again", for: .normal)
                                sender.isEnabled = true
                            }
                        })
                        DispatchQueue.main.async {
                            sender.setTitle("Almost done...", for: .normal)
                        }
                    } else {
                        DispatchQueue.main.async {
                            sender.setTitle("Generating report file (\(round(progress / 100) * 10000)%)", for: .normal)
                        }
                    }
                })
            } catch {
                sender.setTitle("Could not create error report. Please, try again", for: .normal)
                sender.isEnabled = true
            }
        }
    }

    private var eyebrowBackgroundColors = [
        UIColor(red: 0.133, green: 0.137, blue: 0.117, alpha: 1.0),
        UIColor(red: 0.968, green: 0.968, blue: 0.968, alpha: 1.0),
        .white
    ]

    private func updateBackground() {

        if (!UIDevice.current.hasAnEyebrow || !editorLoaded) {
            view.backgroundColor = userPreferences.currentTheme.background
            return
        }

        let orientation = UIApplication.shared.statusBarOrientation

        if orientation == .landscapeRight {
            view.backgroundColor = userPreferences.currentTheme.isDark ?
                    eyebrowBackgroundColors[0] :
                    eyebrowBackgroundColors[1]
        } else if orientation == .landscapeLeft {
            view.backgroundColor = userPreferences.currentTheme.isDark ?
                    eyebrowBackgroundColors[0] :
                    eyebrowBackgroundColors[2]
        } else {
            view.backgroundColor = userPreferences.currentTheme.background
        }
    }

    // MARK: Support of devices with an eyebrow

    func transitionManager(animation: Bool = true) {
        updateBackground()

        if #available(iOS 11.0, *), UIDevice.current.hasAnEyebrow {
            let orientation = UIApplication.shared.statusBarOrientation
            if orientation == .landscapeRight {
                let instance = PrimarySplitViewController.instance(for: view)!
                if instance.isCollapsed ||
                           instance.displayMode == .primaryHidden {
                    leftEditorConstraint?.constant = 44
                } else {
                    leftEditorConstraint?.constant = 0
                }
                rightEditorConstraint?.constant = 0
            } else if orientation == .landscapeLeft {
                leftEditorConstraint?.constant = 0
                rightEditorConstraint?.constant = -44
            } else {
                leftEditorConstraint?.constant = 0
                rightEditorConstraint?.constant = 0
            }

        } else {
            leftEditorConstraint?.constant = 0
            rightEditorConstraint?.constant = 0
        }
        if animation {
            UIView.animate(withDuration: 0.3, animations: view.layoutIfNeeded)
        } else {
            updateViewConstraints()
        }
    }

    // MARK: Keyboard frame update handler

    private var bottomInset: CGFloat = 0

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        bottomEditorConstraint?.constant = -bottomInset
    }

    private func setWebViewBottomInset(_ inset: CGFloat) {

        guard delegate != nil else {
            return
        }

        if (isReadonly) {
            return
        }
        bottomInset = inset - (tabBarController?.tabBar.frame.height ?? 50)
        bottomInset = max(0, bottomInset)

        //print(bottomInset)

        bottomEditorConstraint?.constant = -bottomInset
    }

    func keyboardWillHide(sender: NSNotification) {

        guard delegate != nil else {
            return
        }

        setWebViewBottomInset(0)

        view.layoutSubviews()

        lastFoundKeyboardHeight = 0
    }

    final func keyboardDidHide(sender: NSNotification) {

        guard delegate != nil else {
            return
        }

        if (codeAutocompletionEnabled) {
            predictiveTextView.hide()
        }
    }

    var isReadonlyMessageShown = false

    func keyboardWillShow(sender: NSNotification) {

        guard delegate != nil else {
            return
        }

        if (isReadonly || isKeyboardLocked) {
            view.endEditing(true)
        } else {
            if webView.firstResponder != nil && codeAutocompletionEnabled {
                predictiveTextView.predictiveTextField.fieldDelegate = self
                predictiveTextView.becomeVisible()
            }
        }
    }

    @objc func showReadonlyWarning() {

        guard delegate != nil else {
            return
        }

        if (isReadonlyMessageShown) {
            return
        }
        isReadonlyMessageShown = true
        let controller = (tabBarController as! WebEditorController)
        controller.setTitle(localize("readonly", .editor))
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
            self.isReadonlyMessageShown = false
            controller.setTitle(self.file.name)
        }
    }

    var lastFoundKeyboardHeight: CGFloat = 0

    func keyboardWillChangeFrame(sender: NSNotification) {

        // Not sure how expactly it happens, but there was some crash reports telling that it happens.
        guard delegate != nil else {
            return
        }

        if (isReadonly) {
            return
        }

        let userInfo = sender.userInfo!
        var offset: CGSize = (userInfo[UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue.size

        // Check if keyboard is floating

        if offset.width < UIScreen.main.bounds.width {
            offset.height = 0
        }
        let time = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
        var y: CGFloat

        if isKeyboardLocked {
            y = 0
        } else {
            y = max(0, offset.height);
        }

        if (y > lastFoundKeyboardHeight) {
            let dispatchTime = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(time * 1000000000))

            lastFoundKeyboardHeight = y

            DispatchQueue.main.asyncAfter(deadline: dispatchTime) {
                self.setWebViewBottomInset(self.lastFoundKeyboardHeight)
                self.view.layoutSubviews()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if (time == 0) {
                        self.webView.evaluateJavaScript("editor.setSelection(editor.getCursor(true),editor.getCursor(false))", completionHandler: nil)
                    } else {
                        self.webView.evaluateJavaScript("""
                                                        (function(){
                                                        var y=scrollDiv.scrollTop;
                                                        editor.setSelection(editor.getCursor(true),editor.getCursor(false));
                                                        var dy=scrollDiv.scrollTop-y;
                                                        scrollDiv.scrollTop=y;
                                                        var k=0,dk=1/30;
                                                        function p(){
                                                        k+=dk;
                                                        scrollDiv.scrollTop=y+dy*(1 - Math.cos(Math.PI * k))/2
                                                        if(k<1) {
                                                        requestAnimationFrame(p)
                                                        }else{
                                                        editor.replaceSelection("")
                                                        }
                                                        }
                                                        p()
                                                        return scrollDiv.scrollTop
                                                        })()
                                                        """, completionHandler: {
                            result, error in
                            if let result = result as? Int {
                                self.wkOffset.y = CGFloat(result)
                            }
                        })
                    }
                }
            }
        } else {
            setWebViewBottomInset(y)
            UIView.setAnimationsEnabled(false)
            view.layoutSubviews()
            UIView.setAnimationsEnabled(true)
        }
        lastFoundKeyboardHeight = y
    }

    @objc func makeHapticFeedback() {
        if UIDevice.current.produceSimpleHapticFeedback() {
            if #available(iOS 10.0, *) {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
            }
        }
    }

    // MARK: Scaling PinchGestureRecognizer callbacks

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    private var startScale: CGFloat = 1.0
    private var pinchLocationBuffer: CGPoint!

    @objc func pinchGestureAction(_ sender: UIPinchGestureRecognizer) {
        if sender.state == .began {
            startScale = preferredScale
            pinchLocationBuffer = sender.location(in: webView)
        } else if sender.state == .ended || sender.state == .cancelled {
            pinchLocationBuffer = nil
        } else {
            if sender.numberOfTouches == 2 {
                preferredScale = startScale * sender.scale
                preferredScale = max(1, preferredScale)
                preferredScale = min(webView.scrollView.maximumZoomScale, preferredScale)

                let oldScale = webView.scrollView.zoomScale

                webView.scrollView.zoomScale = preferredScale

                let location = sender.location(in: webView)
                var deltaX = pinchLocationBuffer.x - location.x
                var deltaY = pinchLocationBuffer.y - location.y

                let normalizedY = location.y / webView.bounds.height

                pinchLocationBuffer = location

                // Y-axis alignment

                let deltaOffsetY =
                        preferredContentOffset.y / oldScale -
                                preferredContentOffset.y / preferredScale

                preferredContentOffset.y += deltaOffsetY

                let oldHeight = webView.frame.height * oldScale
                let newHeight = webView.frame.height * preferredScale

                preferredContentOffset.y += (newHeight - oldHeight) * normalizedY

                deltaX /= preferredScale
                deltaY /= preferredScale

                scrollBy(x: deltaX, y: deltaY)

                webView.scrollView.contentOffset = preferredContentOffset
            }
        }
    }


    // MARK: LongPressGestureRecognizer callbacks designed to prevent unwanted text selection

    var isScrollLocked = false

    private func lockScroll() {
        isScrollLocked = true
    }

    private func unlockScroll() {
        isScrollLocked = false
    }

    private var wkOffset = CGPoint.zero
    private var offsetAfterLastCursorUpdate = CGPoint.zero
    private var cursorUpdateLimit: CGFloat = 3

    private func scrollBy(x: CGFloat, y: CGFloat) {

        if x == 0 && y == 0 {
            return
        }

        DispatchQueue.main.async {

            let oldX = Int(self.wkOffset.x), oldY = Int(self.wkOffset.y)

            self.wkOffset.x += x
            self.wkOffset.y += y

            let newX = Int(round(self.wkOffset.x))
            let newY = Int(round(self.wkOffset.y))

            let rx = max(0, newX)
            let ry = max(0, newY)

            // Update scroll position only if its rounded value is actially changed.
            // JavaScript does now allow to scroll for non-integer number

            if oldX == rx && oldY == ry {
                return
            }

            var shouldUpdateCursor = "0"

            // Scroll optimization

            if abs(self.offsetAfterLastCursorUpdate.x - self.wkOffset.x) > self.cursorUpdateLimit ||
                       abs(self.offsetAfterLastCursorUpdate.y - self.wkOffset.y) > self.cursorUpdateLimit {
                shouldUpdateCursor = "1"
                self.offsetAfterLastCursorUpdate = self.wkOffset
            }

            self.webView?.evaluateJavaScript("""
                                             (function(){
                                             var m=scrollDiv;oldx=\(rx);oldy=\(ry);m.scrollLeft=oldx;m.scrollTop=oldy;
                                             if(\(shouldUpdateCursor)){
                                             var s=window.getSelection(),c=s.rangeCount,r=[];
                                             while(c--)r.push(s.getRangeAt(c));
                                             s.removeAllRanges();
                                             r.forEach(function(a){s.addRange(a)})
                                             }
                                             return [m.scrollLeft,m.scrollTop]})
                                             ()
                                             """, completionHandler: {
                [weak self] result, error in

                guard let self = self else {
                    return
                }

                if let response = result as? [Int] {

                    let offsetX = response[0]
                    let offsetY = response[1]

                    var deltaY = CGFloat(offsetY)
                    var deltaX = CGFloat(offsetX)

                    deltaY = CGFloat(newY) - deltaY
                    deltaX = CGFloat(newX) - deltaX

                    self.wkOffset.y -= deltaY
                    self.wkOffset.x -= deltaX

                    if deltaY == 0 {
                        return
                    }

                    let scrollView = self.webView.scrollView

                    deltaY *= scrollView.zoomScale

                    var ry = self.preferredContentOffset.y + deltaY

                    let maxY = scrollView.contentSize.height - scrollView.bounds.height

                    if (ry <= 0) {
                        ry = 0
                    } else if (ry >= maxY) {
                        ry = maxY
                    }

                    self.preferredContentOffset = CGPoint(x: 0, y: ry)

                    self.webView.scrollView.contentOffset = self.preferredContentOffset
                }
            }
            )
        }
    }

    @objc func longPressGestureAction(_ sender: UIPinchGestureRecognizer) {
        if sender.state == .ended || sender.state == .failed || sender.state == .cancelled {
            unlockScroll()
        } else if (sender.state == .began) {
            lockScroll()
        }
    }

    // MARK: Scroll handling

    private var _velocity: CGPoint? = nil
    private var deceleratingVelocity: CGPoint? {
        get {
            _velocity
        }
        set {
            if _velocity == newValue {
                return
            }

            _velocity = newValue

            if delegate != nil && isReadonly {
                return
            }

            if Thread.isMainThread {
                if _velocity == nil {
                    unlockKeyboard()
                } else {
                    lockKeyboard()
                }
            }
        }
    }
    private var deceleratingDelta: CGFloat = 20.0

    private var touchPoint: CGPoint? = nil

    @objc func touchStart(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            deceleratingVelocity = nil
        } else if sender.state == .ended {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                if (self.deceleratingVelocity == nil) {
                    self.unlockKeyboard()
                }
            })
        }
    }

    @objc func touchDidMove(_ sender: UIPanGestureRecognizer) {
        if sender.state == .ended || sender.state == .failed || sender.state == .cancelled {
            touchPoint = nil
            if (isScrollLocked) {
                unlockKeyboard()
                return
            }

            let velocity = sender.velocity(in: webView)
            deceleratingVelocity = velocity

            let dd: CGFloat = 0.7
            let fps: CGFloat = 60.0

            var scrollByX: CGFloat = 0
            var scrollByY: CGFloat = 0

            let zoom = webView.scrollView.zoomScale

            DispatchQueue(label: "easyhtml.editor.scrollinganimationqueue").async {

                [weak self] in

                let dt: TimeInterval = TimeInterval(1.0 / fps)
                var dx = velocity.x / -fps, dy = velocity.y / -fps
                var time = Date(timeIntervalSinceNow: dt)
                var rdx = dx > 0 ? -dd : dd
                var rdy = dy > 0 ? -dd : dd

                dx /= zoom
                dy /= zoom
                rdx /= zoom
                rdy /= zoom

                while self != nil && self!.deceleratingVelocity != nil {
                    scrollByX += dx
                    scrollByY += dy

                    dy += rdy
                    dx += rdx

                    if (dx > 0) != (rdx <= 0) {
                        dx = 0
                        rdx = 0
                    }
                    if (dy > 0) != (rdy <= 0) {
                        dy = 0
                        rdy = 0
                    }

                    if rdx == 0 && rdy == 0 {
                        self?.deceleratingVelocity = nil
                        DispatchQueue.main.async {
                            [weak self] in
                            self?.unlockKeyboard()
                        }
                        break
                    }

                    self?.deceleratingVelocity?.x = dx
                    self?.deceleratingVelocity?.y = dy

                    if abs(scrollByY) >= 1 || abs(scrollByX) >= 1 {
                        self?.scrollBy(x: scrollByX, y: scrollByY)
                        scrollByX = 0
                        scrollByY = 0
                    }

                    Thread.sleep(until: time)
                    time = Date(timeIntervalSinceNow: dt)
                }

                if let y = self?.deceleratingVelocity?.y, y != 0 {
                    self?.deceleratingVelocity!.x = 0
                } else {
                    self?.deceleratingVelocity = nil
                }
            }

            return
        } else if (sender.state == .changed) {
            if isScrollLocked {
                return
            }
            if touchPoint != nil {
                let newLocation = sender.location(in: webView)

                let x = (touchPoint!.x - newLocation.x) / webView.scrollView.zoomScale
                let y = (touchPoint!.y - newLocation.y) / webView.scrollView.zoomScale

                scrollBy(x: x, y: y)

                touchPoint!.x -= touchPoint!.x - newLocation.x
                touchPoint!.y -= touchPoint!.y - newLocation.y
            }
        } else if (sender.state == .began) {
            touchPoint = sender.location(in: webView)
            deceleratingVelocity = nil
            lockKeyboard()
        } else {
            unlockKeyboard()
        }
    }

    private func preventWordSelection() {
        // Prevent long-press gesture from selecting text

        let responder = webView.firstResponder

        if let gestureRecognizers = responder?.gestureRecognizers {
            for recognizer in gestureRecognizers {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
            }
        }
    }

    private var isKeyboardLocked = false

    private func lockKeyboard() {
        guard delegate != nil else {
            return
        }
        guard !isReadonly else {
            return
        }
        guard !isKeyboardLocked else {
            return
        }

        webView.evaluateJavaScript("editor.setOption('readOnly', true)", completionHandler: nil)
        isKeyboardLocked = true
    }

    private func unlockKeyboard() {
        guard delegate != nil else {
            return
        }
        guard !isReadonly else {
            return
        }
        guard isKeyboardLocked else {
            return
        }

        webView.evaluateJavaScript("editor.setOption('readOnly', false)", completionHandler: nil)
        isKeyboardLocked = false
    }

    var preferredContentOffset: CGPoint = .zero

    func scrollViewDidScroll(_ scrollView: UIScrollView) {

        let maxY = scrollView.contentSize.height - scrollView.bounds.height

        if (preferredContentOffset.y > maxY) {
            preferredContentOffset.y = maxY
        }
        if (preferredContentOffset.y < 0) {
            preferredContentOffset.y = 0
        }

        preferredScale = min(preferredScale, 2.0)

        if scrollView.zoomScale != preferredScale {
            scrollView.zoomScale = preferredScale
        }

        if scrollView.contentOffset != preferredContentOffset {
            scrollView.contentOffset = preferredContentOffset
        }
    }

    var preferredScale: CGFloat = 1.0
    var zoomEnabled = !userPreferences.enabledPlugins.contains("lineWrapping")

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if !zoomEnabled {
            scrollView.zoomScale = 1
            return
        }

        scrollViewDidScroll(scrollView)

        webView.evaluateJavaScript("document.querySelector('body>.CodeMirror').style.maxWidth='\(100 / scrollView.zoomScale)%'", completionHandler: nil)

        deceleratingVelocity = nil
    }

    // MARK: JavaScript Prompt


    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {

        let alert = TCAlertController.getNew()

        let responder = self.webView.firstResponder
        responder?.resignFirstResponder()

        alert.applyDefaultTheme()
        alert.contentViewHeight = 30
        alert.constructView()
        alert.headerText = localize("enterabbreviation")
        let textField = alert.addTextField()

        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none

        if #available(iOS 11.0, *) {
            textField.smartDashesType = .no
            textField.smartQuotesType = .no
            textField.smartInsertDeleteType = .no
        }

        view.window!.rootViewController!.present(alert, animated: false, completion: {
            textField.becomeFirstResponder()
        })

        /* NOT WEAK! */ var delegate: OnTextFieldReturned! = nil

        func complete(_ result: String?) {
            guard delegate != nil else {
                return
            }
            textField.resignFirstResponder()

            delegate = nil

            completionHandler(result)
        }

        delegate = OnTextFieldReturned(textField: textField) {
            if (delegate == nil) {
                return
            }
            alert.dismissWithAnimation()
            complete(textField.text)
        }

        alert.addAction(action: TCAlertAction(text: "OK", action: { (_, _) in
            complete(textField.text)
        }, shouldCloseAlert: true))

        alert.addAction(action: TCAlertAction(text: localize("cancel"), action: { (_, _) in
            complete(nil)
        }, shouldCloseAlert: true))

        alert.makeCloseableByTapOutside()

        alert.onClose = {
            complete(nil)
        }
    }

    func deviceRotated() {
        if UIDevice.current.hasAnEyebrow {
            transitionManager()
        }
    }

    func focus() {
        becomeFirstResponder()
    }

    func showKeyboard() {
        webView.becomeFirstResponder()

        // Without this line, the cursor disappears after opening and closing spotlight on the iPad

        webView.evaluateJavaScript("editor.getInputField().blur();editor.getInputField().focus()", completionHandler: nil)
    }

    deinit {

        clearNotificationHandling()
        webView?.scrollView.delegate = nil

        // timer?.invalidate()
        // timer = nil
    }
}

private class OnTextFieldReturned: NSObject, UITextFieldDelegate {
    var completion: () -> ()

    init(textField: UITextField, completion: @escaping () -> ()) {
        self.completion = completion

        super.init()

        textField.delegate = self
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        completion()
        return true
    }
}

extension UIView {

    fileprivate func subviewWithClassName(_ className: String) -> UIView? {

        if NSStringFromClass(type(of: self)) == className {
            return self
        } else {
            for subview in subviews {
                return subview.subviewWithClassName(className)
            }
        }
        return nil
    }

    fileprivate func swizzle() {
        swizzleMethod(#selector(canPerformAction), withSelector: #selector(swizzledCanPerformAction))
    }

    private func swizzleMethod(_ currentSelector: Selector, withSelector newSelector: Selector) {
        if let currentMethod = instanceMethod(for: currentSelector),
           let newMethod = instanceMethod(for: newSelector) {

            method_exchangeImplementations(currentMethod, newMethod)
        } else {
            assertionFailure("No original method")
        }
    }

    private func instanceMethod(for selector: Selector) -> Method? {
        let classType = type(of: self)
        return class_getInstanceMethod(classType, selector)
    }

    @objc private func swizzledCanPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.select(_:)) ||
                   action == #selector(UIResponderStandardEditActions.selectAll(_:)) ||
                   action == #selector(UIResponderStandardEditActions.copy(_:)) ||
                   action == #selector(UIResponderStandardEditActions.paste(_:)) ||
                   action == #selector(UIResponderStandardEditActions.cut(_:)) ||
                   action == #selector(SwizzledWebView.searchOccurrences) ||
                   action == #selector(SwizzledWebView.replaceOccurrences) {
            return swizzledCanPerformAction(action, withSender: sender) // super.canPerformAction
        }

        return false
    }
}
