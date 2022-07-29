//
//  EditorPredictiveTextMenu.swift
//  EasyHTML
//
//  Created by Артем on 17/09/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

private var sharedTextChecker = UITextChecker()

extension UITextChecker {
    static func getSuggestions(for string: String, language: String) -> (suggestions: [String]?, sourceWord: String?) {
        
        var lastWord: String!
        var lastWordRange: Range<String.Index>!
        
        string.enumerateSubstrings(in: string.startIndex ..< string.endIndex, options: [.byWords, .reverse]) { (string, range, _, stop) in
            lastWord = string
            lastWordRange = range
            stop = true
        }
        
        guard lastWord != nil, lastWordRange != nil else { return (nil, nil) }
        
        if lastWordRange.upperBound < string.endIndex {
            lastWord = " "
            let endIndex = string.endIndex
            lastWordRange = string.index(before: endIndex)..<endIndex
        }
        
        let range = NSRange(lastWordRange, in: string)
        
        var guesses = [String]()
        
        if sharedTextChecker.rangeOfMisspelledWord(in: string, range: range, startingAt: 0, wrap: true, language: language).location != NSNotFound {
            guesses = sharedTextChecker.guesses(forWordRange: range, in: string, language: language) ?? []
        } else {
            guesses = sharedTextChecker.completions(forPartialWordRange: range, in: string, language: language) ?? []
        }
        
        if guesses.isEmpty {
            return (nil, lastWord)
        }
        
        return (guesses, lastWord)
    }
}

fileprivate class PredictiveTextItemView: UIView, UIGestureRecognizerDelegate {
    
    func updateWidth() {
        label.sizeToFit()
        if label.frame.size.width < 20 {
            label.frame.size.width = 20
        }
        
        frame.size.width = label.frame.size.width + 10
    }
    
    func setHeight(height: CGFloat) {
        self.frame.size.height = height
        label.frame.origin.y = height / 2 - label.frame.size.height / 2
    }
    
    weak var parent: PredictiveTextField!
    var label = UILabel(frame: CGRect(x: 5, y: 0, width: 0, height: 15))
    var index = -1
    var gestureRecognizer: UILongPressGestureRecognizer!
    
    var item: PredictiveTextItem! {
        didSet {
            label.text = item.title
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func standardInitialise() {
        
        label.backgroundColor = .black
        addSubview(label)
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.backgroundColor = .clear
        updateColor()
        
        gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(tap))
        gestureRecognizer.minimumPressDuration = 0
        gestureRecognizer.delegate = self
        addGestureRecognizer(gestureRecognizer)
        
        layer.cornerRadius = 3
        clipsToBounds = true
    }
    
    static var selectedLightColor = UIColor(white: 0.9, alpha: 1)
    static var normalLightColor = UIColor(white: 0.75, alpha: 1)
    
    static var selectedDarkColor = UIColor(red: 0.2, green: 0.22, blue: 0.24, alpha: 1)
    static var normalDarkColor = UIColor(red: 0.25, green: 0.27, blue: 0.29, alpha: 1)
    
    static var lightTextColor = UIColor.white
    static var darkTextColor = UIColor.black
    
    var selectedColor: UIColor {
        return
            userPreferences.currentTheme.isDark &&
            userPreferences.adjustKeyboardAppearance ?
            PredictiveTextItemView.selectedDarkColor :
            PredictiveTextItemView.selectedLightColor
    }
    
    var normalColor: UIColor {
        return
            userPreferences.currentTheme.isDark &&
            userPreferences.adjustKeyboardAppearance ?
            PredictiveTextItemView.normalDarkColor :
            PredictiveTextItemView.normalLightColor
    }
    
    var textColor: UIColor {
        return
            userPreferences.currentTheme.isDark &&
            userPreferences.adjustKeyboardAppearance ?
            PredictiveTextItemView.lightTextColor :
            PredictiveTextItemView.darkTextColor
    }
    
    var toggled = false
    
    @objc func tap(sender: UILongPressGestureRecognizer) {
        
        if sender.state == .ended && toggled {
            parent?.tappedViewAt(index: index)
        }
        
        if sender.state == .began {
            backgroundColor = selectedColor
            toggled = true
        } else if sender.state == .ended || sender.state == .cancelled || sender.state == .failed {
            backgroundColor = normalColor
            toggled = false
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        standardInitialise()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        standardInitialise()
    }
    
    final func updateColor() {
        backgroundColor = normalColor
        label.textColor = textColor
    }
}

struct PredictiveTextItem {
    let title: String;
    var userInfo: NSDictionary!;
    
    init(title: String) {
        self.title = title
    }
    
    init(title: String, userInfo: NSDictionary!) {
        self.title = title
        self.userInfo = userInfo
    }
}

class PredictiveTextField: UIScrollView, UIScrollViewDelegate {
    

    fileprivate var subviewsCache = [PredictiveTextItemView]()
    fileprivate var currentItems = [PredictiveTextItem]()
    
    private var lockScrollHandling = false
    weak var fieldDelegate: EditorPredictiveTextFieldDelegate!
    
    private var lastInvisibleViewOffsetX: CGFloat = 0
    
    var isEmpty: Bool {
        return currentItems.isEmpty
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        guard !lockScrollHandling && !subviews.isEmpty else { return }
        
        var scroll = contentOffset.x
        
        scroll = max(scroll, 0)
        scroll = min(scroll, max(contentSize.width - bounds.width, 0))
        
        var firstView: PredictiveTextItemView!
        var lastView: PredictiveTextItemView!
        
        let viewHeight = min(35, frame.size.height - 5)
        
        for view in subviews {
            
            guard let view = view as? PredictiveTextItemView else { return }
            
            let maxX = view.frame.maxX
            let minX = view.frame.origin.x
            
            view.gestureRecognizer.isEnabled = false
            view.gestureRecognizer.isEnabled = true
            
            if maxX - scroll <= 0 { // Если оно очень слева
                view.removeFromSuperview()
                lastInvisibleViewOffsetX = maxX + 10
                
                if subviews.isEmpty {
                    lastView = view
                }
            }
            
            if minX - scroll > bounds.width { // Если оно очень справа
                view.removeFromSuperview()
                if let first = subviews.last {
                    contentSize.width = first.frame.maxX + 20
                } else {
                    contentSize.width = 0
                }
                
                if subviews.isEmpty {
                    firstView = view
                }
            }
        }
        
        let y = (bounds.height - viewHeight) / 2
        
        repeat {
            let view = (subviews.first as? PredictiveTextItemView ?? firstView)!
            
            if view.index <= 0 || view.frame.origin.x - scroll <= 10 {
                break
            }
            
            let newView = getFreeView()
            
            insertSubview(newView, at: 0)
            
            let index = view.index - 1
            
            newView.label.text = currentItems[index].title
            newView.index = index
            
            newView.updateWidth()
            newView.setHeight(height: viewHeight)
            
            newView.frame.origin = CGPoint(
                x: view.frame.origin.x - 20 - newView.label.frame.size.width,
                y: y
            )
            
        } while(true)
        
        repeat {
            let view = (subviews.last as? PredictiveTextItemView ?? lastView)!
            
            if view.frame.maxX - scroll >= bounds.width - 10 || view.index >= currentItems.count - 1 {
                break
            }
            
            let newView = getFreeView()
            
            addSubview(newView)
            
            let index = view.index + 1
            
            newView.label.text = currentItems[index].title
            newView.index = index
            
            newView.updateWidth()
            newView.setHeight(height: viewHeight)
            
            newView.frame.origin = CGPoint(
                x: view.frame.maxX + 10,
                y: y
            )
            
            contentSize.width = newView.frame.maxX + 20
            
        } while(true)
    }
    
    func tappedViewAt(index: Int) {
        fieldDelegate?.tappedSuggestion(currentItems[index])
    }
    
    func setPredictiveTextItems(items: [PredictiveTextItem]) {
        currentItems = items
        
        lockScrollHandling = true
        contentOffset.x = 0
        lastInvisibleViewOffsetX = 0
        lockScrollHandling = false
        
        updateViews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let layer = CAGradientLayer()
        layer.frame = bounds
        layer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 0)
        
        // При таких маленьких коэфицентах градиент работает немного
        // странно. Проблему частично решает ненулевой порог.
        
        let factor0 = Float(5 / bounds.width)
        let factor1 = Float(30 / bounds.width)
        let factor2 = 1 - factor1
        let factor3 = 1 - factor0
        
        layer.locations = [
            NSNumber(value: factor0),
            NSNumber(value: factor1),
            NSNumber(value: factor2),
            NSNumber(value: factor3)
        ]
        
        scrollViewDidScroll(self)
        updateInsets()
        
        self.layer.mask = layer
    }
    
    private func getFreeView() -> PredictiveTextItemView {
        for view in subviewsCache {
            if view.superview == nil {
                return view
            }
        }
        
        return createNewView()
    }
    
    private func createNewView() -> PredictiveTextItemView {
        let view = PredictiveTextItemView()
        subviewsCache.append(view)
        view.parent = self
        return view
    }
    
    func updateViews() {
        
        let viewHeight = min(35, frame.size.height - 5)
        
        contentInset.left = 0
        
        let count = currentItems.count
        
        guard count > 0 else {
            for view in subviews {
                view.removeFromSuperview()
            }
            return
        }
        
        let subviewsCopy = subviews
        
        var x: CGFloat = 20
        
        let y = (bounds.height - viewHeight) / 2
        
        var maxIndex = 0
        
        for i in 0 ..< count {
            
            maxIndex = i
            
            let view: PredictiveTextItemView
            
            if subviews.count <= i {
                view = getFreeView()
                addSubview(view)
            } else {
                view = subviews[i] as! PredictiveTextItemView
            }
            
            view.label.text = currentItems[i].title
            view.index = i
            
            view.updateWidth()
            view.setHeight(height: viewHeight)
            
            view.frame.origin = CGPoint(
                x: x,
                y: y
            )
            
            x += view.frame.width + 10
            
            if x > bounds.width { break }
        }
        
        if maxIndex < subviewsCopy.count {
            
            for i in maxIndex + 1 ..< subviewsCopy.count {
                subviewsCopy[i].removeFromSuperview()
            }
        }
        
        contentSize = CGSize(width: x + 10, height: bounds.height)
        
        updateInsets()
    }
    
    private func updateInsets() {
        
        if contentSize.width < bounds.width {
            contentInset.left = (bounds.width - contentSize.width) / 2
        }
    }
    
    private func standardInitialise() {
        isMultipleTouchEnabled = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        delegate = self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        standardInitialise()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        standardInitialise()
    }
    
}

protocol EditorPredictiveTextFieldDelegate: class {
    func tappedSuggestion(_ suggestion: PredictiveTextItem)
}

class EditorPredictiveTextMenu: UIVisualEffectView, NotificationHandler {
    
    static let shared = EditorPredictiveTextMenu()
    
    private let closeButtonWidth: CGFloat = 50
    private var closeButtonInitiated = false
    
    lazy var closeKeyboardButton: UIButton = {
        let button = UIButton()
        button.setImage(#imageLiteral(resourceName: "dismisskeyboard").withRenderingMode(.alwaysTemplate), for: .normal)
        button.imageView!.tintColor = .lightGray
        button.imageView!.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.addTarget(self, action: #selector(closeKeyboard), for: .touchUpInside)
        closeButtonInitiated = true
        return button
    }()
    
    private var borderView = UIView()
    let predictiveTextField = PredictiveTextField()
    
    func suggest(items: [PredictiveTextItem]) {
        predictiveTextField.setPredictiveTextItems(items: items)
    }
    
    @objc func closeKeyboard() {
        UIApplication.shared.keyWindow?.endEditing(false)
    }
    
    private func standardInitialise() {
        
        setupKeyboardWillShowNotificationHandling()
        setupKeyboardWillChangeFrameNotificationHandling()
        setupKeyboardDidChangeFrameNotificationHandling()
        
        contentView.addSubview(predictiveTextField)
        borderView.backgroundColor = UIColor(white: 0.85, alpha: 1)
    }
    
    func refreshField() {
        
    }
    
    var shouldEnableBackdropBlur = true
    
    var leftOffset: CGFloat = 0
    var rightOffset: CGFloat = 0
    var topOffset: CGFloat = 0
    
    func getKeyboardView() -> UIView? {
        
        leftOffset = 0
        rightOffset = 0
        topOffset = 0
        
        func findSubview(in view: UIView, name: String) -> UIView? {
            if NSStringFromClass(type(of: view)) == name {
                return view
            }
            
            for subview in view.subviews {
                if let subview = findSubview(in: subview, name: name) {
                    return subview
                }
            }
            
            return nil
        }
        
        if #available(iOS 13.0, *) {
            guard let keyboardWindow = UIApplication.shared.windows.first(where: {
                return NSStringFromClass(type(of: $0)) == "UIRemoteKeyboardWindow"
            }) else { return nil }
            
            guard let barView = findSubview(in: keyboardWindow, name: "TUISystemInputAssistantView") else {
                return nil
            }
            
            shouldEnableBackdropBlur = false
            
            if barView.frame.width != UIScreen.main.bounds.width {
                topOffset = 2
                for subview in barView.subviews {
                    if subview != self {
                        subview.isHidden = true
                    }
                }
                return barView
            }
                
            for subview in barView.subviews {
                
                guard NSStringFromClass(type(of: subview)).contains("ButtonBarView") else {
                    if subview != self {
                        subview.isHidden = true
                    }
                    continue
                }
                
                guard let assistantView = findSubview(in: subview, name: "TUIAssistantButtonBarGroupView") else {
                    continue
                }
                
                if subview.frame.minX < barView.frame.width / 2 {
                    leftOffset = max(leftOffset, assistantView.bounds.width + 10)
                } else {
                    rightOffset = max(rightOffset, assistantView.bounds.width + 10)
                }
            }
            
            return barView
        } else {
            let barClassName = "UIKeyboardAssistantBar"
            
            if let keyboardWindow = UIApplication.shared.windows.first(where: {
                return NSStringFromClass(type(of: $0)) == "UIRemoteKeyboardWindow"
            }), let ipadBarView = findSubview(in: keyboardWindow, name: barClassName) {
                shouldEnableBackdropBlur = false
                
                for subview in ipadBarView.subviews {
                    
                    guard NSStringFromClass(type(of: subview)).contains("BarStackView") else {
                        continue
                    }
                    
                    if subview.frame.minX == 0 {
                        leftOffset = max(leftOffset, subview.bounds.width)
                    } else if subview.frame.maxX == ipadBarView.bounds.width {
                        rightOffset = max(rightOffset, subview.bounds.width)
                    }
                }
                
                return ipadBarView
            }
            
            shouldEnableBackdropBlur = true
            
            guard let window = UIApplication.shared.windows.first(where: {
                guard NSStringFromClass(type(of: $0)) == "UITextEffectsWindow" else { return false }
                guard let controller = $0.rootViewController else { return false}
                guard NSStringFromClass(type(of: controller)) == "UIInputWindowController" else { return false }
                
                return true
            }) else { return nil }
            
            return window.rootViewController!.view.subviews.first(where: { view -> Bool in
                return NSStringFromClass(type(of: view)) == "UIInputSetHostView"
            })
        }
    }
    
    private init(effect: UIBlurEffect.Style) {
        fatalError()
    }
    
    override func layoutSubviews() {
        
        guard superview != nil && isVisible else {
            return
        }
        
        _becomeVisible()
        
        var leftMargin: CGFloat = 0
        var rightMargin: CGFloat = 0
        
        if UIDevice.current.hasAnEyebrow {
            let orientation = UIApplication.shared.statusBarOrientation
            if orientation == .landscapeLeft {
                rightMargin = 40
            } else if orientation == .landscapeRight {
                leftMargin = 40
            }
        }
        
        UIView.setAnimationsEnabled(false)
        
        if shouldEnableBackdropBlur {
            
            contentView.addSubview(borderView)
            
            if closeKeyboardButton.superview == nil {
                contentView.addSubview(closeKeyboardButton)
            }
            
            frame = CGRect(
                x: 0,
                y: 0,
                width: superview!.bounds.width,
                height: 44
            )
            
            predictiveTextField.frame = CGRect(
                x: leftMargin,
                y: 0,
                width: bounds.width - closeButtonWidth - leftMargin - rightMargin,
                height: 44
            )
            
            borderView.frame = CGRect(
                x: 0,
                y: 0,
                width: bounds.width,
                height: 1
            )
            
            closeKeyboardButton.frame = CGRect(
                x: bounds.width - closeButtonWidth - rightMargin,
                y: 0,
                width: closeButtonWidth,
                height: bounds.height
            )
        } else {
            
            if closeButtonInitiated {
                closeKeyboardButton.removeFromSuperview()
            }
            
            borderView.removeFromSuperview()
            
            frame = CGRect(
                x: leftOffset + leftMargin,
                y: 0,
                width: superview!.frame.width - leftOffset - rightOffset,
                height: superview!.frame.height
            )
            predictiveTextField.frame = CGRect(
                x: leftMargin,
                y: topOffset,
                width: bounds.width - leftMargin - rightMargin,
                height: bounds.height
            )
        }
        
        UIView.setAnimationsEnabled(true)
        
        super.layoutSubviews()
    }
    
    init() {
        
        super.init(effect: UIBlurEffect(style: .extraLight))
        
        standardInitialise()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        standardInitialise()
    }
    
    func keyboardWillChangeFrame(sender: NSNotification) {
        if !self.isHidden {
            self.becomeVisible()
            self.predictiveTextField.updateViews()
        }
    }
    
    func keyboardDidChangeFrame(sender: NSNotification) {
        DispatchQueue.main.async {
            self.keyboardWillChangeFrame(sender: sender)
        }
    }
    
    func keyboardWillShow(sender: NSNotification) {
        self.isHidden = false
        self.predictiveTextField.subviewsCache.forEach {$0.updateColor()}
        
        if self.isVisible {
            DispatchQueue.main.async {
                self.becomeVisible()
            }
        }
    }
    
    var isVisible: Bool = false
    
    private func _becomeVisible() {
        isVisible = true
        
        guard let view = getKeyboardView() else { return }
        
        if shouldEnableBackdropBlur {
            for view in view.subviews {
                if view != self {
                    view.isHidden = true
                }
            }
            
            effect = UIBlurEffect(style: (userPreferences.currentTheme.isDark && userPreferences.adjustKeyboardAppearance) ? .dark : .extraLight)
        } else {
            effect = nil
        }
        
        view.addSubview(self)
    }
    
    func becomeVisible() {
        
        _becomeVisible()
        
        layoutSubviews()
    }
    
    func hide() {
        isVisible = false
        removeFromSuperview()
    }
    
    deinit {
        clearNotificationHandling()
    }
    
}
