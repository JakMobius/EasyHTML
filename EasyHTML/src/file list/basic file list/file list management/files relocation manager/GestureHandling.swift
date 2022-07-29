//
//  GestureHandling.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

extension FilesRelocationManager {
    @objc internal func gestureRecognizerAction(_ sender: UIPanGestureRecognizer) {
        
        if sender.state == .began {
            startGestureLocation = sender.location(in: replicationViewsContainer.superview)
            
            touchGestureRecognizer.isEnabled = false
            touchGestureRecognizer.isEnabled = true
        }
        
        var location = sender.location(in: replicationViewsContainer.superview)
        location.x -= startGestureLocation!.x
        location.y -= startGestureLocation!.y
        
        let previousTouchLocation = self.previousTouchLocation
        self.previousTouchLocation = location
        
        if sender.state == .ended || sender.state == .failed || sender.state == .cancelled {
            self.previousTouchLocation = nil
            if case .horizontal = currentLayout {
                if isMovingVertical {
                    if draggingFile != nil {
                        if location.y < -100 && !draggingIsLocked && sender.state == .ended {
                            let tag = draggingFile.tag
                            let file = filesToMove[tag]
                            animateCardFlight(index: tag);
                            fileCopied(file: file)
                            self.draggingFile = nil
                            
                            if self.draggingIsLocked {
                                self.unlockDragging()
                            } else {
                                self.restoreGuideSigns()
                            }
                            
                            UIView.animate(withDuration: 0.3) {
                                
                                if self.replicationViews.count == 1 {
                                    let view = self.replicationViews.first!
                                    view.frame.origin.x = 10
                                    view.frame.origin.y = 5
                                }
                                
                                self.replicationViewsContainer.transform = .identity
                                self.layout(force: true)
                            }
                            return
                        }
                        
                        self.draggingFile = nil
                        
                        if self.draggingIsLocked {
                            self.unlockDragging()
                        } else {
                            self.restoreGuideSigns()
                        }
                        
                        UIView.animate(withDuration: 0.3, animations: {
                            self.layout()
                        })
                        return
                    }
                    
                    if location.y > 60 {
                        
                        setEditing(false)
                        
                        if replicationViewsContainer.contentOffset.x != 0 {
                            sender.isEnabled = false
                            replicationViewsContainer.setContentOffset(CGPoint.zero, animated: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                                self.switchToVerticalLayout()
                                sender.isEnabled = true
                            })
                        } else {
                            switchToVerticalLayout()
                        }
                    }
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        self.layout()
                        self.replicationViewsContainer.transform = .identity
                    })
                }
            } else {
                if isMovingHorizontal {
                    if location.x < -10 {
                        cancelFilesRelocation()
                        return
                    } else if location.x > 50 && filesToMove.count > 1 {
                        switchToHorizontalLayout()
                    }
                } else if isMovingVertical {
                    if location.y < -100 && !draggingIsLocked && sender.state == .ended {
                        if filesToMove.count == 1 {
                            let file = filesToMove.first!
                            animateCardFlight(index: 0)
                            fileCopied(file: file)
                        } else {
                            filesCopied()
                            return
                        }
                    } else {
                        restoreGuideSigns()
                    }
                }
                
                UIView.animate(withDuration: 0.3, animations: {
                    if case .normal = self.currentLayout {
                        self.currentLayout = .normal(size: 20)
                    }
                    
                    self.layout()
                    self.replicationViewsContainer.transform = .identity
                })
            }
            
            startGestureLocation = nil
            isMovingVertical = false
            isMovingHorizontal = false
            replicationViewsContainer.isScrollEnabled = true
            self.draggingFile = nil
            self.unlockDragging()
            
            return
        }
        
        if case .horizontal = currentLayout {
            if isMovingVertical {
                
                if location.y < -10 {
                    
                    let translation: CGFloat
                    
                    if draggingIsLocked == true {
                        translation = bounceModify(translation: location.y + 10, coefficent: 3)
                    } else {
                        translation = bounceModify(translation: location.y + 10, coefficent: 30)
                    }
                    
                    if draggingFile == nil {
                        draggingFile = replicationViewsContainer.hitTest(sender.location(in: replicationViewsContainer), with: nil)
                        while draggingFile != nil && !(draggingFile is ReplicationView) {
                            draggingFile = draggingFile.superview
                            
                            if draggingFile == replicationViewsContainer {
                                draggingFile = nil
                            }
                        }
                        
                        if let draggingFile = draggingFile {
                            if let container = parent.topViewController as? SharedFileContainer {
                                let file = filesToMove[draggingFile.tag]
                                
                                let receiveability = container.canReceiveFile(file: file, from: sourceType)
                                
                                if case .no(let reason) = receiveability {
                                    lockDragging(reason: reason)
                                } else {
                                    unlockDragging()
                                    hideSigns()
                                }
                            } else {
                                lockDragging(reason: .unsupportedController)
                            }
                        }
                        
                        draggingFile?.superview?.bringSubviewToFront(draggingFile)
                    }
                    if let draggingfile = draggingFile {
                        
                        draggingfile.transform.ty = 0
                        draggingfile.frame.origin.y = 5
                        draggingfile.transform.ty = translation
                        layout()
                    }
                } else {
                    if draggingIsLocked {
                        unlockDragging()
                    }
                    
                    if draggingFile != nil {
                        draggingFile = nil
                        layout()
                    }
                    
                    if location.y > 10 {
                        var translation = location.y - 10
                        
                        if translation < 60 {
                            translation = bounceModify(translation: translation, coefficent: 6)
                        } else {
                            translation = 60 - bounceModify(translation: 60 - translation, coefficent: 6)
                        }
                        
                        UIView.animate(withDuration: 0.15, animations: {
                            self.replicationViewsContainer.transform = CGAffineTransform(translationX: 0, y: translation)
                        })
                    }
                }
                
            } else if(!isMovingHorizontal) {
                let distance = pow(location.x, 2) + pow(location.y, 2)
                
                if distance > 3 {
                    if abs(location.y) * 2 > abs(location.x) {
                        isMovingVertical = true
                        
                        if location.y < 0 && !draggingIsLocked {
                            if let container = parent.topViewController as? SharedFileContainer {
                                if !container.canReceiveFiles {
                                    lockDragging(reason: .unsupportedController)
                                }
                            } else {
                                lockDragging(reason: .unsupportedController)
                            }
                        }
                        
                        replicationViewsContainer.isScrollEnabled = false
                    } else {
                        isMovingHorizontal = true
                    }
                }
            }
        } else {
            
            if isMovingVertical {
                if location.y >= 0 && draggingIsLocked {
                    unlockDragging()
                } else if location.y < -10 && previousTouchLocation!.y > -10 {
                    guard let controller = parent.topViewController as? FileListController else {
                        lockDragging(reason: .unsupportedController)
                        return
                    }
                    guard !controller.isLoading else {
                        lockDragging(reason: .loadingIsInProcess)
                        return
                    }
                    if !controller.canReceiveFiles {
                        lockDragging(reason: .unsupportedController)
                        return
                    }
                    if filesToMove.count == 1 {
                        let receiveability = controller.canReceiveFile(file: filesToMove.first!, from: sourceType)
                        
                        if case let .no(reason) = receiveability {
                            lockDragging(reason: reason)
                            return
                        }
                    }
                }
                
                handleVerticalGesture(location: location)
            } else if isMovingHorizontal {
                handleHorizontalGesture(location: location)
            } else {
                let distance = pow(location.x, 2) + pow(location.y, 2)
                
                if distance > 3 {
                    
                    isMovingVertical = abs(location.y) * 2 > abs(location.x)
                    
                    isMovingHorizontal = !isMovingVertical
                    
                    if location.y < 0 && isMovingVertical {
                        guard let controller = parent.topViewController as? FileListController else {
                            lockDragging(reason: .unsupportedController)
                            return
                        }
                        
                        guard !controller.isLoading else {
                            lockDragging(reason: .loadingIsInProcess)
                            return
                        }
                        
                        guard controller.canReceiveFiles else{
                            lockDragging(reason: .unsupportedController)
                            return
                        }
                        
                        if filesToMove.count == 1 {
                            let receiveability = controller.canReceiveFile(file: filesToMove.first!, from: sourceType)
                            
                            if case let .no(reason) = receiveability {
                                lockDragging(reason: reason)
                                return
                            }
                        }
                        
                        hideSigns()
                    }
                }
            }
        }
    }
    
    final func lockDragging(reason: RelocationForbiddenReason) {
        guard !draggingIsLocked else { return }
        
        draggingIsLocked = true
        showMovingForbiddenSign(reason: reason)
    }
    
    final func unlockDragging() {
        guard draggingIsLocked else { return }
        
        draggingIsLocked = false
        restoreGuideSigns()
    }
    
    final func setupGestureRecognizers() {
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(gestureRecognizerAction(_:)))
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.delegate = self
        
        touchGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(touchGestureRecognizerAction(_:)))
        touchGestureRecognizer.minimumPressDuration = 0
        touchGestureRecognizer.delegate = self
        
        replicationViewsContainer.addGestureRecognizer(panGestureRecognizer)
        replicationViewsContainer.addGestureRecognizer(touchGestureRecognizer)
    }
    
    @objc internal func touchGestureRecognizerAction(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .ended || sender.state == .failed || sender.state == .cancelled {
            
            delayTask?.cancel()
            delayTask = nil
            
            if case .horizontal = currentLayout {
                if selectedView is ReplicationView {
                    selectedView?.backgroundColor = .white
                    selectedView = nil
                } else if selectedView is UIImageView && selectedView.superview is ReplicationView {
                    if sender.state == .ended {
                        fileDeleted(index: selectedView.superview!.tag)
                    }
                }
            } else if sender.state == .ended, filesToMove.count > 1, case .normal(_) = currentLayout {
                switchToHorizontalLayout()
            }
        } else if sender.state == .began {
            if case .horizontal = currentLayout {
                
                selectedView = replicationViewsContainer.hitTest(sender.location(in: replicationViewsContainer), with: nil)
                
                while selectedView != nil && !(selectedView is ReplicationView) {
                    selectedView = selectedView.superview
                    
                    if selectedView == replicationViewsContainer {
                        selectedView = nil
                    }
                }
                
                if selectedView == nil {
                    return
                }
                
                if isEditing {
                    let deleteButton = (selectedView as! ReplicationView).deleteButton
                    
                    if deleteButton.frame.contains(sender.location(in: deleteButton)) {
                        selectedView = deleteButton
                        deleteButton.alpha = 0.5
                    } else {
                        selectedView = nil
                        return
                    }
                } else {
                    delayTask = DispatchWorkItem(block: {
                        self.setEditing(true)
                    })
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: delayTask)
                    selectedView?.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
                }
            }
        }
    }
    
    final func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    final func handleHorizontalGesture(location: CGPoint) {
        if(location.x < -10) {
            replicationViewsContainer.transform = CGAffineTransform(translationX: location.x, y: 0)
            
            createCancelIcon()
            
            let translation = -location.x - 10
            let alpha = min(1 - min(translation / 100, 0.8), 1)
            
            replicationViewsContainer.alpha = alpha
        } else {
            removeCancelIcon()
            
            if location.x > 10 {
                
                if filesToMove.count == 1 {
                    replicationViewsContainer.transform = CGAffineTransform(translationX: bounceModify(translation: location.x - 10, coefficent: 30), y: 0)
                    return
                }
                
                replicationViewsContainer.transform = .identity
                
                let currentTranslation = location.x - 10
                let targetTranslation: CGFloat = 200
                var percentage = currentTranslation / targetTranslation
                let antiPercentage = max(0, 1 - percentage)
                
                if percentage > 1 {
                    percentage = bounceModify(translation: percentage - 1, coefficent: 2) + 1
                }
                
                var offset: CGFloat = 0
                var targetX: CGFloat = 0
                let dOffset = CGFloat(20 / replicationViewsContainer.subviews.count)
                
                for subview in replicationViewsContainer.subviews {
                    //let sourcePoint = CGPoint(x: offset, y: offset)
                    //let targetPoint = CGPoint(x: targetX, y: 0)
                    
                    let currentPoint = CGPoint(
                        x: offset * antiPercentage + targetX * percentage,
                        y: offset * antiPercentage
                        // sourcePoint.x * antiPercentage + targetPoint.y * percentage
                        // sourcePoint.y * antiPercentage + targetPoint.y * percentage
                        
                        // Как говорится в том анекдоте: "Так, как ты сказал, тоже можно"
                        // Но оптимизация. Слишком много уж мы квадратных корней в секунду считаем.
                        // Закомментированное сверху решение более широкое и многофункциональное,
                        // но нас оно не интересует. Мы можем упростить алгоритм, так как наша
                        // анимация с точки зрения реализации довольно простая.
                    )
                    
                    subview.transform = CGAffineTransform(translationX: currentPoint.x, y: currentPoint.y)
                    
                    offset += dOffset
                    targetX += 96
                }
            }
        }
    }
    
    internal func handleVerticalGesture(location: CGPoint) {
        let width = parent.view.frame.width
        let height = (parent.view.frame.height - 200)
        let coefficent = width / height
        
        var yTranslation = location.y
        
        if yTranslation > 0 {
            yTranslation = bounceModify(translation: yTranslation, coefficent: 10)
        } else if filesToMove.count == 1 {
            yTranslation = bounceModify(translation: yTranslation, coefficent: 30)
        } else {
            let xTranslation = location.x / 10
            
            if !draggingIsLocked {
                let top = height + yTranslation
                let maxTop = height * 0.6
                if top < maxTop {
                    let overflow = maxTop - top
                    yTranslation += overflow
                    yTranslation -= bounceModify(translation: overflow, coefficent: 50)
                }
            } else {
                yTranslation = bounceModify(translation: yTranslation, coefficent: 3)
            }
            
            replicationViewsContainer.transform = CGAffineTransform(translationX: xTranslation, y: yTranslation)
            
            var size = -yTranslation * coefficent + 20
            size = min(size, width - 100)
            size = max(size, 20)
            
            currentLayout = .normal(size: size)
            
            layout()
            return
        }
        
        replicationViewsContainer.transform = CGAffineTransform(translationX: 0, y: yTranslation)
    }
}
