//
//  EditorWarning.swift
//  EasyHTML
//
//  Created by Артем on 24.04.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

internal class EditorMessageViewManager {

    internal unowned let parent: UIViewController

    internal var additionalTopOffset: CGFloat = 0

    internal var warningViews: [EditorWarning] = []

    internal func recalculatePositions() {

        var offsetTop: CGFloat = additionalTopOffset

        var i = -1
        for view in warningViews {
            i = i + 1
            view.transform = .init(translationX: 0, y: offsetTop)
            offsetTop += view.frame.height + 10
        }
    }

    internal func reset() {
        for view in warningViews {
            view.close()
        }
        warningViews = []
    }

    internal func newWarning(message: String) -> EditorWarning {
        let view = EditorWarning(message: message, manager: self)
        return view
    }

    internal init(parent: UIViewController) {
        self.parent = parent
    }
}

internal class EditorWarning: UIView {

    internal struct Button {
        var title: String
        var target: AnyObject?
        var action: Selector?
    }

    /**
     Message style. Can be applied using the `applyingStyle(style:)` method
     - `.error`: Does not close automatically, can be closed by a touch
     - `.warning`: A message alerting the user to something to pay attention to. Does not close automatically, can be closed by a touch
     - `.success`: A message telling the user that the action was successfully performed. Closes automatically, can be closed by a touch
     - `.white`: Simple white message, closes automatically, can be closed by touch
     */

    internal enum Style {
        case error, warning, success, white
    }

    private var manager: EditorMessageViewManager

    internal func recalculateButtons() {
        var offsetx: CGFloat = 10
        let posY = frame.height - 60
        let deltaOffset = (frame.width - offsetx) / CGFloat(uiButtons.count)
        let width = deltaOffset - 10

        for button in uiButtons {
            button.frame = CGRect(x: offsetx, y: posY, width: width, height: 50)
            offsetx += deltaOffset
        }
    }

    override internal func layoutSubviews() {
        super.layoutSubviews()

        if (doesRecalculatePositionsOnLayoutSubviews) {
            manager.recalculatePositions()
        }

        recalculateButtons()
        if let label = label {

            label.preferredMaxLayoutWidth = frame.width - 20
            label.frame.size.width = label.preferredMaxLayoutWidth
        }
    }

    internal var isCloseable = true
    private var message: String!
    internal var color: UIColor = #colorLiteral(red: 0.7474772135, green: 0.7474772135, blue: 0.7474772135, alpha: 0.8528829225)
    internal var buttonColor: UIColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    internal var textColor: UIColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
    private var doesRecalculatePositionsOnLayoutSubviews = false
    private var label: UILabel!
    internal var buttons: [Button] = []
    internal var uiButtons: [UIButton] = []
    internal var autoClosingEnabled = false

    internal func applyingStyle(style: Style) -> EditorWarning {
        switch style {
        case .white:
            color = #colorLiteral(red: 0.7474772135, green: 0.7474772135, blue: 0.7474772135, alpha: 0.8528829225)
            buttonColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
            textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            autoClosingEnabled = true
            break;
        case .error:
            color = #colorLiteral(red: 1, green: 0.3411764706, blue: 0.3411764706, alpha: 0.7986630722)
            buttonColor = #colorLiteral(red: 1, green: 0.5345489961, blue: 0.5332677092, alpha: 1)
            textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
            autoClosingEnabled = false
            break;
        case .warning:
            color = #colorLiteral(red: 1, green: 0.6784313725, blue: 0.3404854911, alpha: 0.8528829225)
            buttonColor = #colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1)
            textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            autoClosingEnabled = false
            break;
        case .success:
            color = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 0.8483786387)
            buttonColor = #colorLiteral(red: 0.4597121267, green: 0.8401635488, blue: 0.2272140398, alpha: 1)
            textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            autoClosingEnabled = true
            break;
        }

        return self
    }

    internal func withAutoClosingEnabled(_ autoClosingEnabled: Bool) -> EditorWarning {
        self.autoClosingEnabled = autoClosingEnabled
        return self
    }

    internal func withButton(_ button: Button) -> EditorWarning {
        buttons.append(button)
        return self
    }

    internal func addButton(_ button: Button) -> EditorWarning {
        buttons.append(button)
        return self
    }

    internal func withButtonColor(_ color: UIColor) -> EditorWarning {
        buttonColor = color
        return self
    }

    internal func withCloseable(_ isCloseable: Bool) -> EditorWarning {
        self.isCloseable = isCloseable
        return self
    }

    internal func withTextColor(_ color: UIColor) -> EditorWarning {
        textColor = color
        return self
    }

    internal func withColor(_ color: UIColor) -> EditorWarning {
        self.color = color
        return self
    }

    fileprivate init(message: String, manager: EditorMessageViewManager) {
        self.manager = manager
        uiButtons = []
        buttons = []
        self.message = message
        super.init(frame: manager.parent.view.frame)
    }

    internal func present() {
        if manager.warningViews.contains(self) {
            return
        }
        manager.parent.view.addSubview(self)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        layer.cornerRadius = 10.0

        let touchGesture = UITapGestureRecognizer(target: self, action: #selector(hide))
        addGestureRecognizer(touchGesture)

        let leftConstraint = manager.parent.view.leftAnchor.constraint(equalTo: leftAnchor, constant: -20.0)

        leftConstraint.priority = .defaultHigh
        leftConstraint.isActive = true

        manager.parent.view.layoutMarginsGuide.topAnchor.constraint(equalTo: topAnchor, constant: -20.0).isActive = true
        manager.parent.view.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        widthAnchor.constraint(lessThanOrEqualToConstant: 500.0).isActive = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: 50.0).isActive = true

        label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(label)
        label.backgroundColor = .clear
        label.text = message
        label.textColor = textColor
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.numberOfLines = 0
        label.alpha = 0.0

        let screen = UIScreen.main
        if min(screen.bounds.width, screen.bounds.height) < 500 {
            label.font = label.font.withSize(13)
        }

        isUserInteractionEnabled = true

        label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: buttons.isEmpty ? -10 : -70).isActive = true
        label.topAnchor.constraint(equalTo: topAnchor, constant: 10).isActive = true
        label.leftAnchor.constraint(equalTo: leftAnchor, constant: 10).isActive = true

        for button in buttons {

            let uiButton = UIButton(type: .system)
            if let selector = button.action {
                uiButton.addTarget(button.target, action: selector, for: .touchUpInside)
            }

            addSubview(uiButton)

            uiButton.setBackgroundImage(UIImage.getImageFilledWithColor(color: buttonColor.withAlphaComponent(0.5)), for: .disabled)
            uiButton.setBackgroundImage(UIImage.getImageFilledWithColor(color: buttonColor), for: .normal)
            uiButton.setTitle(button.title, for: .normal)
            uiButton.setTitleColor(textColor.withAlphaComponent(0.5), for: .disabled)
            uiButton.layer.cornerRadius = 10.0
            uiButton.layer.masksToBounds = true

            uiButton.setTitleColor(textColor, for: .normal)
            uiButton.alpha = 0

            uiButtons.append(uiButton)
        }

        manager.parent.view.layoutSubviews()
        doesRecalculatePositionsOnLayoutSubviews = true
        manager.warningViews.insert(self, at: 0)

        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn], animations: {
            self.manager.recalculatePositions()
        })
        UIView.animate(withDuration: 0.3, delay: 0.2, options: [.curveEaseOut], animations: {
            self.backgroundColor = self.color
            for button in self.uiButtons {
                button.alpha = 1.0
            }
            self.label.alpha = 1.0
        }, completion: nil)

        if (isCloseable && autoClosingEnabled) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0, execute: {
                if let index = self.manager.warningViews.firstIndex(of: self) {
                    self.manager.warningViews.remove(at: index)
                    UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseOut], animations: {
                        self.alpha = 0.0
                        self.transform = self.transform.translatedBy(x: 0, y: -20)
                        self.manager.recalculatePositions()
                    }, completion: {
                        _ in
                        self.removeFromSuperview()
                    })
                }
            })
        }
    }

    internal func close() {
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.5, animations: {
            self.alpha = 0.0
        }, completion: {
            _ in
            self.removeFromSuperview()
            if let index = self.manager.warningViews.firstIndex(of: self) {
                self.manager.warningViews.remove(at: index)
            }

            UIView.animate(withDuration: 0.5) {
                self.manager.recalculatePositions()
            }
        })
    }

    @objc func hide() {
        if (!isCloseable) {
            return
        }
        close()
    }

    required internal init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) can not be used to initialize instance type EditorWarningVIew. Use init(parent:message:) instead")
    }
}
