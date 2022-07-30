//
//  TCAlertAction.swift
//  Custom Alert View
//
//  Created by Артем on 10.11.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import Foundation
import UIKit

internal class TCAnimation {
    internal var animations: [TCAnimationType]
    internal var duration: Double
    internal static var none = TCAnimation(animation: .none, duration: 0.3)
    internal var delay: Double
    internal var usingSpringWithDamping: CGFloat
    internal var initialSpringVelocity: CGFloat
    internal var options: UIView.AnimationOptions

    internal init(animation: TCAnimationType = .none, duration: Double = 0.3, delay: Double = 0.0, usingSpringWithDamping: CGFloat = 1.0, initialSpringVelocity: CGFloat = 0.0, options: UIView.AnimationOptions = .curveEaseInOut) {
        animations = [animation]
        self.duration = duration
        self.delay = delay
        self.usingSpringWithDamping = usingSpringWithDamping
        self.initialSpringVelocity = initialSpringVelocity
        self.options = options
    }

    internal init(animations: [TCAnimationType] = [], duration: Double = 0.3, delay: Double = 0.0, usingSpringWithDamping: CGFloat = 1.0, initialSpringVelocity: CGFloat = 0.0, options: UIView.AnimationOptions = .curveEaseInOut) {
        self.animations = animations
        self.duration = duration
        self.delay = delay
        self.usingSpringWithDamping = usingSpringWithDamping
        self.initialSpringVelocity = initialSpringVelocity
        self.options = options
    }
}

internal enum TCAnimationType {
    case none
    case move(CGFloat, CGFloat)
    case rotate(CGFloat)
    case scale(CGFloat, CGFloat)
    case opacity
}

internal class TCAlertAction: NSObject {
    internal var text = "Button"
    internal var action: ((UIButton, TCAlertController) -> ())? = nil
    internal var shouldCloseAlert = false
    internal var button: UIButton?
    fileprivate var alertController: TCAlertController! // Prevent controller from deallocation

    internal init(text: String, action: ((UIButton, TCAlertController) -> ())?, shouldCloseAlert: Bool = false) {
        self.text = text
        self.action = action
        self.shouldCloseAlert = shouldCloseAlert
        //"asd".replacingOccurrences(of: <#T##StringProtocol#>, with: <#T##StringProtocol#>)
    }

    internal init(text: String, shouldCloseAlert: Bool = false) {
        self.text = text
        self.shouldCloseAlert = shouldCloseAlert
    }
}

internal class TCAlertController: UIViewController, UITextFieldDelegate, NotificationHandler {
    @IBOutlet var alertView: UIView!
    @IBOutlet var header: UILabel!
    @IBOutlet var buttonsView: UIView!
    @IBOutlet var contentView: UIView!
    @IBOutlet var buttonsViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var contentViewHeightConstraint: NSLayoutConstraint!
    internal var buttonFont: UIFont = UIFont(name: "PingFangHK-Semibold", size: 15) ?? UIFont.systemFont(ofSize: 15)

    internal var buttonColor: UIColor? = UIColor(red: 0, green: 0.478, blue: 1.0, alpha: 1.0)
    internal var buttonHighlightedColor: UIColor? = UIColor(red: 0, green: 0.637, blue: 0.75, alpha: 1.0)

    internal var buttonImage: UIImage? = nil
    internal var buttonHighlightedImage: UIImage? = nil

    internal var buttonHeight: CGFloat = 35;
    internal var buttonContainerSidePadding: CGFloat = 10.0
    internal var buttonMargin: CGFloat = 10.0;
    internal var animation: TCAnimation = TCAnimation(animations: [.opacity, .scale(0.8, 0.8)], duration: 0.5)
    internal var closeAnimation: TCAnimation = TCAnimation(animation: .opacity, duration: 0.3)

    internal var alertCornerRadius: CGFloat = 8.0
    internal var buttonCornerRadius: CGFloat = 3.0

    internal var contentViewHeight: CGFloat = 0.0

    internal var minimumButtonsForVerticalLayout = 3

    internal func applyDefaultTheme() {
        buttonColor = UIColor.white
        buttonHighlightedColor = UIColor(white: 0.9, alpha: 1.0)
        buttonImage = UIImage.getImageFilledWithColor(color: userPreferences.currentTheme.themeColor)
        buttonHighlightedImage = UIImage.getImageFilledWithColor(color: userPreferences.currentTheme.cellSelectedColor)
    }

    /**
     Adds `UITextView` to `contentView` of this `TCAlertController`. The text alignment mode is set to `.center`.
     Disables the ability to edit the content. Designed to create alerts with text on them. With default arguments
     is identical to the following code:
     
         let textView = UITextView()
         textView.frame = CGRect(
            x: 5,
            y: 0,
            width: alert.contentView.frame.width - 10,
            height: alert.contentView.frame.height
         )
         textView.textAlignment = .center
         textView.isEditable = false
     
         alert.addSubview(textView)
     
     Cannot be called before `constructView`. If the indentation values are invalid, they are reset to default values.
     
     - parameter horizontalMargin: Edge indent. The default is 5 pixels. Can't be more than half the width of `contentView` or less than zero
     - parameter topMargin: Top indent from the edge of `contentView`. The default value is zero. Cannot be greater than `contentViewHeight - bottomMargin`.
     - parameter bottomMargin: The indent from the bottom of the edge of `contentView`. The default value is zero. Can't be more than `contentViewHeight - topMargin`.
     
     - returns: Newly added `UITextView`
    */

    internal func addTextView(horizontalMargin: CGFloat = 5, topMargin: CGFloat = 0, bottomMargin: CGFloat = 0) -> UITextView {

        if !viewConstructed {
            fatalError("addTextView: should not be called before constructView()")
        }

        var horizontalMargin = horizontalMargin
        var topMargin = topMargin
        var bottomMargin = bottomMargin

        if (horizontalMargin > 125 || horizontalMargin < 0) {
            print("addTextView: Cannot create UITextView with too large or negative horizontalMargin value. Falling back to zero margin")
            horizontalMargin = 0
        }
        if contentViewHeight - topMargin - bottomMargin < 0 || topMargin < 0 || bottomMargin < 0 {
            print("addTextView: Cannot create UITextView with too large or negative top and bottom margin. Falling back to zero margins")
            bottomMargin = 0
            topMargin = 0
        }

        let textView = UITextView(frame: CGRect(
                x: horizontalMargin,
                y: topMargin,
                width: contentView.frame.width - horizontalMargin,
                height: contentViewHeight - bottomMargin)
        )

        // iOS 13 makes the background black when dark theme is enabled
        textView.backgroundColor = .white
        textView.textColor = .black

        textView.textAlignment = .center
        textView.isEditable = false

        contentView.addSubview(textView)

        return textView
    }

    /**
      Adds `UIActivityIndicatorView` to the center of the `TCAlertController`. The value of the `hidesWhenStopped`
      field is set to `true`. The default is hidden. With default values the method call is identical to the following
      code:
     
         let activityIndicator = UIActivityIndicatorView()
         activityIndicator.frame.origin = CGPoint(
             x: alert.contentView.frame.width / 2 - 16,
             y: alert.contentView.frame.height / 2 - 16
         )
     
         activityIndicator.activityIndicatorViewStyle = .gray
         activityIndicator.hidesWhenStopped = true
     
        alert.contentView.addSubview(activityIndicator)
     
     - parameter offset: Offset of the indicator relative to the center
     - returns: Newly added activity indicator
    */

    internal func addActivityIndicator(offset: CGPoint = .zero) -> UIActivityIndicatorView {

        if !viewConstructed {
            fatalError("addActivityIndicator: should not be called before constructView()")
        }

        let halfSize: CGFloat = 16
        let size: CGFloat = 32

        let activityIndicator = UIActivityIndicatorView()

        activityIndicator.frame = CGRect(
                x: contentView.frame.width / 2 - halfSize + offset.x,
                y: contentViewHeight / 2 - halfSize + offset.y,
                width: size,
                height: size
        )

        activityIndicator.style = .gray
        activityIndicator.hidesWhenStopped = true
        activityIndicator.stopAnimating()

        contentView.addSubview(activityIndicator)

        return activityIndicator
    }

    /**
     Adds `UIProgressView` into the `TCAlertController`
     
     - parameter offset: Offset from the center
     - parameter padding: Left and right padding
     - returns
     */

    internal func addProgressView(offset: CGPoint = .zero, padding: CGFloat = 10) -> UIProgressView {

        if !viewConstructed {
            fatalError("addProgressView: should not be called before constructView()")
        }

        let progressView = UIProgressView()
        contentView.addSubview(progressView)
        progressView.frame = CGRect(x: padding + offset.x, y: contentViewHeight / 2 - 1 + offset.y, width: contentView.frame.width - (padding * 2), height: 2)

        return progressView
    }

    /**
     Adds `UITextField` into the `TCAlertController`. Setups keyboard style, sets `returnKeyType` to `.done`
     */

    internal func addTextField(horizontalMargin: CGFloat = 15, topMargin: CGFloat = 0, height: CGFloat = 30) -> UITextField {

        if !viewConstructed {
            fatalError("addTextField: cannot be called before constructView()")
        }


        var horizontalMargin = horizontalMargin
        var topMargin = topMargin

        if (horizontalMargin > 125 || horizontalMargin < 0) {
            print("addTextField: Cannot create UITextView with too large or negative horizontalMargin value. Falling back to zero margin")
            horizontalMargin = 0
        }
        if contentViewHeight - topMargin < 0 || topMargin < 0 {
            print("addTextField: Cannot create UITextView with too large or negative top margin. Falling back to zero margins")
            topMargin = 0
        }

        let textField = UITextField(frame: CGRect(
                x: horizontalMargin,
                y: topMargin,
                width: contentView.frame.width - horizontalMargin * 2,
                height: height)
        )

        textField.keyboardAppearance = userPreferences.currentTheme.isDark ? .dark : .light
        textField.delegate = self
        textField.layer.borderColor = userPreferences.currentTheme.themeColor.cgColor
        textField.layer.borderWidth = 1.0
        textField.layer.masksToBounds = true
        textField.layer.cornerRadius = 3.0
        textField.setLeftPaddingPoints(6.0)
        textField.returnKeyType = .done

        contentView.addSubview(textField)

        return textField
    }

    override internal func viewWillAppear(_ animated: Bool) {
        var transform = alertView.transform

        animation.animations.forEach {
            animation in
            switch (animation) {
            case let .move(x, y):
                transform = transform.translatedBy(x: x, y: y)
                break;
            case let .scale(x, y):
                transform = transform.scaledBy(x: x, y: y)
                break;
            case let .rotate(a):
                transform = transform.rotated(by: a)
            case .opacity:
                view.alpha = 0.0
                break
            default: break;
            }
        }
        alertView.transform = transform
        view.backgroundColor = userPreferences.currentTheme.background.withAlphaComponent(0.5)
        alertView.layer.cornerRadius = alertCornerRadius
        alertView.layer.shadowColor = UIColor(white: 0.0, alpha: 0.5).cgColor
        alertView.layer.shadowOpacity = 1.0
        alertView.layer.shadowOffset = CGSize(width: 3, height: 3)
        alertView.layer.shadowRadius = 13.0
        buttonsView.layer.cornerRadius = alertCornerRadius
    }

    /// Called when the window is closed by clicking outside of it

    var onClose: (() -> ())! = nil

    func makeCloseableByTapOutside() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(closeByGesture(_:)))
        let tapView = UIView()
        tapView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(tapView, at: 0)

        tapView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tapView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tapView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tapView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        tapView.backgroundColor = UIColor.clear
        tapView.addGestureRecognizer(gesture)
    }

    func getParentAlertController() -> TCAlertController? {
        let parent = presentingViewController
        return parent as? TCAlertController
    }

    func dismissAllAlertControllers() {
        dismiss(animated: false)
        removeFromParent()
        view.removeFromSuperview()
        (presentingViewController as? TCAlertController)?.dismissAllAlertControllers()
    }

    func getParentAlertControllersList(includeSelf: Bool = false) -> [TCAlertController] {
        var result: [TCAlertController] = includeSelf ? [self] : []

        var node = presentingViewController
        while (node is TCAlertController) {
            result.append(node as! TCAlertController)
            node = node?.presentingViewController
        }

        return result
    }

    override internal func viewDidAppear(_ animated: Bool) {
        view.frame = view.superview!.bounds
        UIView.animate(withDuration: animation.duration,
                delay: animation.delay,
                usingSpringWithDamping: animation.usingSpringWithDamping,
                initialSpringVelocity: animation.initialSpringVelocity,
                options: animation.options,
                animations: {
                    self.alertView.transform = CGAffineTransform.identity
                    self.view.alpha = 1.0
                })
    }

    internal var buttons: [UIButton] = []

    internal static func getNew() -> TCAlertController {
        UIStoryboard(name: "Misc", bundle: nil).instantiateViewController(withIdentifier: "alertViewController") as! TCAlertController
    }

    internal var headerText: String {
        get {
            header.text ?? ""
        }
        set {
            header.text = newValue
        }
    }

    private(set) var viewConstructed = false

    private var actions: [TCAlertAction] = []

    internal func clearActions() {
        actions = []
        buttons.forEach {
            button in
            button.removeFromSuperview()
        }
        buttons = []
    }

    internal func addAction(action: TCAlertAction) {
        actions.append(action)

        if viewConstructed {
            setupButton(action: action)

            reCalculateActionsPositions()
        }
    }

    private func setupButton(action: TCAlertAction) {
        action.button = UIButton()
        action.button!.setTitle(action.text, for: .normal)
        if (buttonColor != nil) {
            action.button?.setTitleColor(buttonColor, for: .normal)
        }
        if (buttonHighlightedColor != nil) {
            action.button?.setTitleColor(buttonHighlightedColor, for: .highlighted)
        }

        action.button!.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)

        action.button!.setBackgroundImage(buttonImage, for: .normal)
        action.button!.setBackgroundImage(buttonHighlightedImage, for: .highlighted)

        action.button!.contentEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        action.button!.titleLabel?.adjustsFontSizeToFitWidth = true
        action.button!.titleLabel?.minimumScaleFactor = 0.8
        action.button!.layer.cornerRadius = buttonCornerRadius
        action.button!.clipsToBounds = true
        action.button!.titleLabel?.font = buttonFont
        action.button!.isEnabled = action.action != nil || action.shouldCloseAlert
        action.alertController = self

        buttonsView.addSubview(action.button!)

        buttons.append(action.button!)
    }

    internal func constructView() {
        if (viewConstructed) {
            return;
        }

        view.backgroundColor = UIColor(white: 0.5, alpha: 0.7)

        actions.forEach {
            action in

            setupButton(action: action)
        }

        reCalculateActionsPositions()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        contentViewHeightConstraint.constant = contentViewHeight

        viewConstructed = true
    }

    internal func reCalculateActionsPositions() {

        let actionCount = actions.count
        let rowStacked = actionCount < minimumButtonsForVerticalLayout
        var actionIndex: CGFloat = 0
        let width = rowStacked ? (buttonsView.frame.width - buttonContainerSidePadding * 2 + buttonMargin) / CGFloat(actionCount) : -1
        let actionSize = CGSize(width: rowStacked ? width - buttonMargin : buttonsView.frame.width - buttonContainerSidePadding * 2, height: buttonHeight)

        var x = buttonContainerSidePadding
        var y = contentViewHeight == 0 ? 0 : buttonMargin
        let deltaY = buttonHeight + buttonMargin

        actions.forEach {
            action in

            action.button?.frame = CGRect(origin: CGPoint(
                    x: x,
                    y: y
            ), size: actionSize)

            if (rowStacked) {
                x += width
            } else {
                y += deltaY
            }

            actionIndex += 1
        }

        if (rowStacked) {
            y += deltaY
        }

        buttonsViewHeightConstraint.constant = y - buttonMargin + buttonContainerSidePadding

        buttonsView.layoutSubviews()
    }

    func translateTo(animation: TCAnimation, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: animation.duration,
                delay: animation.delay,
                usingSpringWithDamping: animation.usingSpringWithDamping,
                initialSpringVelocity: animation.initialSpringVelocity,
                options: animation.options,
                animations: {
                    var opacity = false
                    var transform = CGAffineTransform.identity
                    animation.animations.forEach {
                        animation in

                        switch (animation) {
                        case let .move(x, y):
                            transform = transform.translatedBy(x: x, y: y)
                            break;
                        case let .scale(x, y):
                            transform = transform.scaledBy(x: x, y: y)
                            break;
                        case let .rotate(a):
                            transform = transform.rotated(by: a)
                        case .opacity:
                            opacity = true
                            self.view.alpha = 0.0
                        default: break;
                        }
                    }
                    if (!opacity) {
                        self.view.alpha = 1.0
                    }
                    self.alertView.transform = transform
                }, completion: completion)
    }

    @objc func closeByGesture(_ sender: UITapGestureRecognizer) {
        onClose?()
        dismissWithAnimation()
    }

    internal func dismissWithAnimation() {
        translateTo(animation: closeAnimation, completion: {
            _ in
            self.dismissAllAlertControllers()
        })
    }

    @objc func buttonAction(_ sender: UIButton) {
        for action in actions where action.button == sender {
            action.action?(sender, self)
            if (action.shouldCloseAlert) {
                dismissWithAnimation()
            }
            return
        }
    }

    func keyboardWillHide(sender: NSNotification) {
        view.frame.size.height = UIScreen.main.bounds.height
        UIView.animate(withDuration: 0.25, animations: { () -> Void in
            self.view.layoutSubviews()
        })
    }

    func keyboardWillShow(sender: NSNotification) {
        let userInfo = sender.userInfo!
        var offset: CGSize = (userInfo[UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue.size

        // Check if keyboard is floating

        if offset.width < UIScreen.main.bounds.width {
            offset.height = 0
        }

        view.frame.size.height = max(UIScreen.main.bounds.height - offset.height, alertView.frame.height + 40)

        view.setNeedsLayout()
        UIView.animate(withDuration: 0.25, animations: { () -> Void in
            self.view.layoutIfNeeded()
        })
    }

    override func viewDidDisappear(_ animated: Bool) {
        for action in actions {
            action.alertController = nil
        }
    }

    internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }

    internal func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }
}

