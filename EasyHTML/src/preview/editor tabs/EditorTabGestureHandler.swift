//
//  EditorTabGestureHandler.swift
//  EasyHTML
//
//  Created by Артем on 04.08.2022.
//  Copyright © 2022 Артем. All rights reserved.
//

import Foundation
import simd

protocol EditorTabGestureHandlerDelegate : AnyObject {
    func tabPressed(editorTabGesture: EditorTabGestureHandler, at position: CGPoint)
    func tabHighlighted(editorTabGesture: EditorTabGestureHandler)
    func tabUnHighlighted(editorTabGesture: EditorTabGestureHandler)
    func tabDidSlide(_: EditorTabGestureHandler)
    func tabWillSlide(_: EditorTabGestureHandler)
    func tabDidEndSlide(_: EditorTabGestureHandler)
}

class EditorTabGestureHandler: NSObject, UIGestureRecognizerDelegate {
    
    var enabled = true {
        didSet {
            panRecognizer.isEnabled = enabled
            pressRecognizer.isEnabled = enabled
        }
    }
    var isTabRemovable = true
    weak var delegate: EditorTabGestureHandlerDelegate?
    var view: UIView
    
    private var panRecognizer: UIPanGestureRecognizer!
    private var pressRecognizer: UILongPressGestureRecognizer!
    private var panMovement: SIMD2<Float> = .zero
    private(set) var slideVelocity: CGFloat = 0
    private(set) var slideMovement: CGFloat = 0
    private var touchConfirmed = false
    private var touchFailed = false
    private var isTap = false
    
    init(view: UIView) {
        self.view = view
        
        super.init()
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panRecognizer.maximumNumberOfTouches = 1
        panRecognizer.delegate = self

        pressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handlePress))
        pressRecognizer.minimumPressDuration = 0
        pressRecognizer.delegate = self
        pressRecognizer.allowableMovement = .infinity
    
        view.addGestureRecognizer(panRecognizer)
        view.addGestureRecognizer(pressRecognizer)
    }
    
    @objc func handlePress(_ sender: UILongPressGestureRecognizer) {
        guard enabled else {
            return
        }

        if sender.state == .began {
            delegate?.tabHighlighted(editorTabGesture: self)
            isTap = true
        } else if sender.state == .ended || sender.state == .cancelled || sender.state == .failed {
            delegate?.tabUnHighlighted(editorTabGesture: self)

            if (!isTap || sender.state != .ended) {
                return
            }

            let location = sender.location(in: view)

            delegate?.tabPressed(editorTabGesture: self, at: location)
        }
    }
    
    private func bounceEffect(dx: CGFloat) -> CGFloat {
        if dx > 0 {
            return (sqrt(dx / 10 + 1) - 1) * 10
        } else if !isTabRemovable {
            return -(sqrt(-dx / 10 + 1) - 1) * 10
        }
        return dx
    }
    
    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        guard enabled else {
            return
        }
        
        if sender.state == .began {
            panMovement = .zero
            isTap = true
        } else if sender.state == .changed {

            if (isTap) {
                isTap = sender.translation(in: view) == .zero
            }

            if !touchConfirmed && !touchFailed {
                panMovement += Self.vector(from: sender.translation(in: view))

                if (length(panMovement) > 5) {
                    if panMovement.y == 0 {
                        touchConfirmed = true
                    } else if abs(panMovement.x / panMovement.y) > 1 {
                        touchConfirmed = true
                    } else {
                        touchFailed = true
                        panRecognizer.isEnabled = false
                        panRecognizer.isEnabled = true
                    }

                    if touchConfirmed {
                        delegate?.tabWillSlide(self)
                    }
                }
                return
            }

            if touchFailed {
                return
            }
            
            slideVelocity = sender.velocity(in: view).x
            slideMovement = bounceEffect(dx: CGFloat(panMovement.x))
            delegate?.tabDidSlide(self);

        } else if sender.state == .ended {
            
            if touchConfirmed {
                delegate?.tabDidEndSlide(self)
            }
            
            slideVelocity = 0
            slideMovement = 0

            touchConfirmed = false
            touchFailed = false
        } else if sender.state == .failed || sender.state == .cancelled {
            panMovement = .zero
            slideMovement = 0

            if touchConfirmed {
                delegate?.tabDidEndSlide(self)
            }
            touchConfirmed = false
            touchFailed = false
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith shouldRecognizeSimultaneouslyWithGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
    private static func vector(from cgPoint: CGPoint) -> SIMD2<Float> {
        return SIMD2<Float>(Float(cgPoint.x), Float(cgPoint.y))
    }
}
