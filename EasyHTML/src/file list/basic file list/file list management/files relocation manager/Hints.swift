//
//  HintType.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//


extension FilesRelocationManager {
    enum HintType {
        case normal, horizontal
        
        public var key: String {
            return self == .normal ? "movehint" : "movehinthorizontal"
        }
        
        public var iterations: Int {
            return 3
        }
        
        public func localizedTextForIteration(_ iteration: Int) -> String {
            return localize(/*# -tcanalyzerignore #*/"\(key)\(iteration)", .files)
        }
    }
    
    final var shouldPreviewGuide: Bool {
        get {
            return Defaults.bool(forKey: "fileMovingGuideShouldPreview", def: true)
        }
        set {
            Defaults.set(newValue, forKey: "fileMovingGuideShouldPreview")
        }
    }
    
    final var shouldPreviewHorizontalGuide: Bool {
        get {
            return Defaults.bool(forKey: "fileMovingHorizontalGuideShouldPreview", def: true)
        }
        set {
            Defaults.set(newValue, forKey: "fileMovingHorizontalGuideShouldPreview")
        }
    }
    
    final func showGuideMessage() {
        
        createSign(text: hintType.localizedTextForIteration(1))
        
        hintTimer?.invalidate()
        
        currentSign.tag = 1
        
        hintTimer = Timer.scheduledTimer(timeInterval: 4, target: self, selector: #selector(updateGuide), userInfo: nil, repeats: true)
        
    }
    
    final func removeGuide() {
        if let sign = self.currentSign {
            self.currentSign = nil
            UIView.animate(withDuration: 0.3, animations: {
                sign.alpha = 0
            }, completion: {
                _ in
                sign.removeFromSuperview()
            })
        }
    }
    
    @objc func updateGuide() {
        
        if let sign = self.currentSign {
            
            var i = sign.tag
            
            if i >= hintType.iterations {
                i = 1
            } else {
                i += 1
            }
            
            self.currentSign?.label.setTextWithFadeAnimation(text: hintType.localizedTextForIteration(i), duration: 0.5, completion: nil)
            
            sign.tag = i
        }
    }
    
    final func createSign(text: String) {
        
        guard currentSign == nil else {
            currentSign.label.setTextWithFadeAnimation(text: text)
            return
        }
        
        currentSign = WarningSign()
        
        currentSign.onClose = {
            let sign = self.currentSign
            self.currentSign = nil
            
            if case .horizontal = self.currentLayout {
                self.shouldPreviewHorizontalGuide = false
            } else {
                self.shouldPreviewGuide = false
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                sign?.alpha = 0.0
            }, completion: {
                _ in
                sign?.removeFromSuperview()
            })
        }
        
        currentSign.label.text = text
        
        currentSign.translatesAutoresizingMaskIntoConstraints = false
        
        parent.view.addSubview(currentSign)
        
        currentSign.centerXAnchor.constraint(equalTo: parent.view.centerXAnchor).isActive = true
        currentSign.bottomAnchor.constraint(equalTo: replicationViewsContainer.topAnchor, constant: -10).isActive = true
        
        let widthConstraint = currentSign.widthAnchor.constraint(equalTo: parent.view.widthAnchor, multiplier: 0.9, constant: 0)
        widthConstraint.priority = .defaultHigh
        widthConstraint.isActive = true
        
        currentSign.widthAnchor.constraint(lessThanOrEqualToConstant: 500).isActive = true
        currentSign.layer.cornerRadius = 10
        currentSign.layer.masksToBounds = true
        currentSign.alpha = 0.0
        
        UIView.animate(withDuration: 0.5) {
            self.currentSign.alpha = 1.0
        }
    }
    
    final func hideSigns() {
        guard currentSign != nil else { return }
        let sign = self.currentSign!
        self.currentSign = nil
        
        UIView.animate(withDuration: 0.5, animations: {
            sign.alpha = 0.0
        }, completion: {
            _ in
            sign.removeFromSuperview()
        })
        
    }
    
    final func restoreGuideSigns() {
        guard currentSign == nil || currentSign!.tag == -1 else { return }
        
        if case .horizontal = self.currentLayout {
            if self.shouldPreviewHorizontalGuide {
                self.hintType = .horizontal
                self.showGuideMessage()
            } else {
                hideSigns()
            }
        } else if self.shouldPreviewGuide {
            self.hintType = .normal
            self.showGuideMessage()
        } else {
            hideSigns()
        }
    }
    
}
