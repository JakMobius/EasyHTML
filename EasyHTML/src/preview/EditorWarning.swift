//
//  EditorWarningview.swift
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
     Стиль предупреждения. Может быть применен при помощи метода `applyingStyle(style:)`
     - `.error`: Сообщение, говорящее об ошибке. Не закрывается автоматически, может быть закрыто касанием
     - `.warning`: Сообщение, предупреждающее о том, на что пользователь должен обратить внимание. Не закрывается автоматически, может быть закрыто касанием
     - `.success`: Сообщение, говорящее о успешно совершенном действии. Закрывается автоматически, может быть закрыто касанием
     - `.white`: Простое белое сообщение, закрывается автоматически, может быть закрыто касанием
     */
    
    internal enum Style {
        case error, warning, success, white
    }
    
    private var manager: EditorMessageViewManager
    
    internal func recalculateButtons() {
        var offsetx: CGFloat = 10
        let posY = self.frame.height - 60
        let deltaoffset = (self.frame.width - offsetx) / CGFloat(uibuttons.count)
        let width = deltaoffset - 10
        
        for button in uibuttons {
            button.frame = CGRect(x: offsetx, y: posY, width: width, height: 50)
            offsetx += deltaoffset
        }
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        if(doesRecalculatePositionsOnLayoutSubviews) {
            manager.recalculatePositions()
        }
        
        recalculateButtons()
        if let label = label {
            
            label.preferredMaxLayoutWidth = self.frame.width - 20
            label.frame.size.width = label.preferredMaxLayoutWidth
        }
    }
    
    internal var isCloseable = true
    private var message: String!
    internal var color: UIColor = #colorLiteral(red: 0.7474772135, green: 0.7474772135, blue: 0.7474772135, alpha: 0.8528829225)
    internal var buttoncolor: UIColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    internal var textcolor: UIColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
    private var doesRecalculatePositionsOnLayoutSubviews = false
    private var label: UILabel!
    internal var buttons: [Button] = []
    internal var uibuttons: [UIButton] = []
    internal var autoClosingEnabled = false
    
    internal func applyingStyle(style: Style) -> EditorWarning {
        switch style {
        case .white:
            self.color = #colorLiteral(red: 0.7474772135, green: 0.7474772135, blue: 0.7474772135, alpha: 0.8528829225)
            self.buttoncolor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
            self.textcolor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            self.autoClosingEnabled = true
            break;
        case .error:
            self.color = #colorLiteral(red: 1, green: 0.3411764706, blue: 0.3411764706, alpha: 0.7986630722)
            self.buttoncolor = #colorLiteral(red: 1, green: 0.5345489961, blue: 0.5332677092, alpha: 1)
            self.textcolor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
            self.autoClosingEnabled = false
            break;
        case .warning:
            self.color = #colorLiteral(red: 1, green: 0.6784313725, blue: 0.3404854911, alpha: 0.8528829225)
            self.buttoncolor = #colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1)
            self.textcolor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            self.autoClosingEnabled = false
            break;
        case .success:
            self.color = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 0.8483786387)
            self.buttoncolor = #colorLiteral(red: 0.4597121267, green: 0.8401635488, blue: 0.2272140398, alpha: 1)
            self.textcolor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            self.autoClosingEnabled = true
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
        self.buttoncolor = color
        return self
    }
    
    internal func withCloseable(_ isCloseable: Bool) -> EditorWarning {
        self.isCloseable = isCloseable
        return self
    }
    
    internal func withTextColor(_ color: UIColor) -> EditorWarning {
        self.textcolor = color
        return self
    }
    
    internal func withColor(_ color: UIColor) -> EditorWarning {
        self.color = color
        return self
    }
    
    fileprivate init(message: String, manager: EditorMessageViewManager) {
        self.manager = manager
        self.uibuttons = []
        self.buttons = []
        self.message = message
        super.init(frame: manager.parent.view.frame)
    }
    
    internal func present() {
        if manager.warningViews.contains(self) {
            return
        }
        manager.parent.view.addSubview(self)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = .clear
        self.layer.cornerRadius = 10.0
        
        let touchGesture = UITapGestureRecognizer(target: self, action: #selector(hide))
        self.addGestureRecognizer(touchGesture)
        
        let leftConstraint = manager.parent.view.leftAnchor.constraint(equalTo: self.leftAnchor, constant: -20.0)
        
        leftConstraint.priority = .defaultHigh
        leftConstraint.isActive = true
        
        manager.parent.view.layoutMarginsGuide.topAnchor.constraint(equalTo: self.topAnchor, constant: -20.0).isActive = true
        manager.parent.view.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.widthAnchor.constraint(lessThanOrEqualToConstant: 500.0).isActive = true
        self.heightAnchor.constraint(greaterThanOrEqualToConstant: 50.0).isActive = true
        
        label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        self.addSubview(label)
        label.backgroundColor = .clear
        label.text = message
        label.textColor = self.textcolor
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.numberOfLines = 0
        label.alpha = 0.0
        
        let screen = UIScreen.main
        if min(screen.bounds.width, screen.bounds.height) < 500 {
            label.font = label.font.withSize(13)
        }
        
        isUserInteractionEnabled = true
        
        label.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: self.buttons.isEmpty ? -10 : -70).isActive = true
        label.topAnchor.constraint(equalTo: self.topAnchor, constant: 10).isActive = true
        label.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 10).isActive = true
        
        for button in self.buttons {
            
            let uibutton = UIButton(type: .system)
            if let selector = button.action {
                uibutton.addTarget(button.target, action: selector, for: .touchUpInside)
            }
            
            addSubview(uibutton)
            
            uibutton.setBackgroundImage(UIImage.getImageFilledWithColor(color: buttoncolor.withAlphaComponent(0.5)), for: .disabled)
            uibutton.setBackgroundImage(UIImage.getImageFilledWithColor(color: buttoncolor), for: .normal)
            uibutton.setTitle(button.title, for: .normal)
            uibutton.setTitleColor(textcolor.withAlphaComponent(0.5), for: .disabled)
            uibutton.layer.cornerRadius = 10.0
            uibutton.layer.masksToBounds = true
            
            uibutton.setTitleColor(textcolor, for: .normal)
            uibutton.alpha = 0
            
            uibuttons.append(uibutton)
        }
        
        manager.parent.view.layoutSubviews()
        doesRecalculatePositionsOnLayoutSubviews = true
        self.manager.warningViews.insert(self, at: 0)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn], animations: {
            self.manager.recalculatePositions()
        })
        UIView.animate(withDuration: 0.3, delay: 0.2, options: [.curveEaseOut], animations: {
            self.backgroundColor = self.color
            for button in self.uibuttons {
                button.alpha = 1.0
            }
            self.label.alpha = 1.0
        }, completion: nil)
        
        if(isCloseable && autoClosingEnabled) {
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
        self.isUserInteractionEnabled = false
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
        if(!isCloseable) {
            return
        }
        close()
    }
    
    required internal init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) can not be used to initialize instance type EditorWarningVIew. Use init(parent:message:) instead")
    }
}
