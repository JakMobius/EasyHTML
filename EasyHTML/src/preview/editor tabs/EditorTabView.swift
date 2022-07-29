
import UIKit

@objc protocol EditorTabViewDelegate: AnyObject {
    @objc optional func tabWillClose(editorTabView: EditorTabView)
}

class EditorTabView: UIView, UIGestureRecognizerDelegate {
    
    override var keyCommands: [UIKeyCommand]? {
        if(parentView.containerViews.count < 2) {
            return []
        }
        
        return [
            UIKeyCommand(input: "[", modifierFlags: [.command, .shift], action: #selector(prevTab), discoverabilityTitle: localize("prevtab")),
            UIKeyCommand(input: "]", modifierFlags: [.command, .shift], action: #selector(nextTab), discoverabilityTitle: localize("nexttab")),
        ]
    }
    
    private func switchToTab(index: Int) {
        
        var index = index
        
        if(index == -1) {
            index = parentView.containerViews.count - 1
        }
        if(index >= parentView.containerViews.count) {
            index = 0
        }
        
        parentView.switchToTab(index: index)
        
//        parentView.animateOut(animated: false, force: false) {
//            self.parentView.animateIn(animated: false, force: false, view: self.parentView.containerViews[index])
//        }
    }
    
    @objc func prevTab() {
        switchToTab(index: self.index - 1)
    }
    
    @objc func nextTab() {
        switchToTab(index: self.index + 1)
    }
    
	var savedOriginY: CGFloat = 0.0
	weak var parentView: EditorSwitcherView!
    var index: Int = 0 {
        didSet {
            layer.zPosition = CGFloat(index)
        }
    }
	var savedTransform: CATransform3D = CATransform3DIdentity
    var panRecognizer: UIPanGestureRecognizer!
    var pressRecognizer: UILongPressGestureRecognizer!
    var navController: TabNavigationController!
    var isRemovable: Bool {
        didSet {
            navController.titleContainer.closeButton.isHidden = !isRemovable
        }
    }
    //var zoomGestureRecognizer: UIPinchGestureRecognizer!
    weak var delegate: EditorTabViewDelegate?
    
    init(frame: CGRect, navigationController: TabNavigationController) {
    
        isRemovable = true
        
		super.init(frame: frame)
        
        isOpaque = true
        
        self.navController = navigationController
        self.navController.parentView = self
        
        backgroundColor = .clear
        layer.backgroundColor = UIColor.clear.cgColor
        
        navController.view.frame = self.bounds
        
        addSubview(navController.view)
        
		savedOriginY = frame.origin.y
		
		//tapRecognizer = UITapGestureRecognizer(target:self, action: #selector(handleTouch))
		
		//tapRecognizer.numberOfTapsRequired = 1
		
		//addGestureRecognizer(tapRecognizer)
		//tapRecognizer.delegate = self
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        
        panRecognizer.maximumNumberOfTouches = 1
        
        addGestureRecognizer(panRecognizer)
        panRecognizer.delegate = self
        
        //zoomGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handleZoom))
        
        //addGestureRecognizer(zoomGestureRecognizer)
        
        pressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handlePress))
        pressRecognizer.minimumPressDuration = 0
        pressRecognizer.delegate = self
        pressRecognizer.allowableMovement = .infinity

        addGestureRecognizer(pressRecognizer)
		
		layer.edgeAntialiasingMask = CAEdgeAntialiasingMask(rawValue:
			CAEdgeAntialiasingMask.layerLeftEdge.rawValue |
				CAEdgeAntialiasingMask.layerRightEdge.rawValue |
				CAEdgeAntialiasingMask.layerBottomEdge.rawValue |
				CAEdgeAntialiasingMask.layerTopEdge.rawValue)
	}
    
    override func didMoveToWindow() {
        if isEditorFocused, window != nil {
            AppDelegate.updateSceneTitle(for: window!)
        }
    }
    
    var isEditorFocused: Bool = false
    
    // TODO: Переделать
    
    func focused(byShortcut: Bool = false) {
        isEditorFocused = true
        if window != nil {
            AppDelegate.updateSceneTitle(for: window!)
        }
        
        let controller = navController.editorViewController
        
        if let controller = controller as? FileEditor {
            controller.editor?.didFocus(byShortcut: byShortcut)
        }
    }
    
    func blured() {
        isEditorFocused = false
        let controller = navController.editorViewController
        
        if let controller = controller as? FileEditor {
            controller.editor?.didBlur()
        }
    }
    
    func setInteractionEnabled(_ enabled: Bool) {
        for view in navController.view.subviews {
            if view is TabTitleContainerView {
                continue
            }
            
            view.isUserInteractionEnabled = enabled
        }
    }
    
    func setGestureRecognisersEnabled(_ enabled: Bool) {
        guard gestureRecognizers != nil else {
            return
        }
        
        //tapRecognizer.isEnabled = enabled
        panRecognizer.isEnabled = enabled
        pressRecognizer.isEnabled = enabled
        
        // zoomGestureRecognizer.isEnabled = !enabled
    }
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.navController.view.frame = self.bounds
    }
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith shouldRecognizeSimultaneouslyWithGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
    
    private var startPanPoint: CGPoint!
    private(set) var slideMovement: CGFloat = 0
    private var touchConfirmed = false
    private var touchFailed = false
    private var isTap = false
    
    // TODO
    
   /* @objc func handleZoom(_ sender: UIPinchGestureRecognizer) {
        if(sender.scale > 1) {
            sender.isEnabled = false
            sender.isEnabled = true
            return
        }
        
        
    }*/
    
    private var initialTransform: CATransform3D!
    
    @objc func handlePress(_ sender: UILongPressGestureRecognizer) {
        let press = !sender.isEnabled || parentView.isFullScreen
        
        if sender.state == .began {
            if press {
                UIView.animate(withDuration: 0.4) {
                    self.initialTransform = self.layer.transform
                    self.layer.transform = CATransform3DScale(self.layer.transform, 1.02, 1.02, 1)
                }
            }
            isTap = true
        } else if sender.state == .ended || sender.state == .cancelled || sender.state == .failed {
            if press {
                if let transform = self.initialTransform {
                    UIView.animate(withDuration: 0.2) {
                        self.layer.transform = transform
                    }
                }
            }
            
            if(!isTap || sender.state != .ended) {
                return
            }
            
            let location = sender.location(in: self)
            
            let buttonFrame = navController.titleContainer.closeButton.frame
            
            let buttonSize = buttonFrame.width + buttonFrame.origin.x * 2
            
            if location.x < buttonSize && location.y < buttonSize && isRemovable {
                closeTab()
                return
            }
            
            if parentView.isFullScreen {
                
                if parentView.containerViews.count == 2 {
                    
                    parentView.animateBottomViewIn()
                    
                } else {
                    parentView.animateOut()
                }
            } else {
                parentView.animateIn(view: self)
            }
        }
    }
    
    internal var viewsIsAppeared = false
    
    internal func viewsDisappeared() {
        guard viewsIsAppeared else { return }
        viewsIsAppeared = false
        
        navController.hideView()
    }

    internal func viewsAppeared() {
        guard !viewsIsAppeared else { return }
        viewsIsAppeared = true
        
        navController.presentView()
    }
    
    /*internal var placeholderImageView: UIImageView!
    
    internal var placeholderImageShown: Bool {
        get {
            return navController.placeholderImageView.image != nil
        }
    }
    
    internal func hideImage() {
        guard placeholderImageView?.image != nil else { return }
        self.navController.view.isHidden = false
        placeholderImageView?.removeFromSuperview()
        placeholderImageView?.image = nil
        
    }*/
    
    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        if parentView.isFullScreen {
            sender.isEnabled = false
            sender.isEnabled = true
            slideMovement = 0
            touchConfirmed = false
            touchFailed = false
            startPanPoint = nil
            isTap = true
            return
        }
        
        if sender.state == .began {
            startPanPoint = sender.location(in: self.superview)
            
            startPanPoint.y -= parentView.scrollView.contentOffset.y
            isTap = true
        } else if sender.state == .changed {
            
            if parentView.isFullScreen {
                return
            }
            
            let location = sender.location(in: self.superview)
            
            if(isTap) {
                isTap = sender.translation(in: self.superview) == .zero
            }
            
            if !touchConfirmed && !touchFailed {
                let x1 = startPanPoint.x
                let y1 = startPanPoint.y
                let x2 = location.x
                let y2 = location.y - parentView.scrollView.contentOffset.y
                let dx = x2 - x1
                let dy = y2 - y1
                
                if(dx * dx + dy * dy > 25) {
                    if dy == 0 {
                        touchConfirmed = true
                        parentView.scrollLockFactor += 1
                    } else if abs(dx / dy) > 1 {
                        touchConfirmed = true
                        parentView.scrollLockFactor += 1
                    } else {
                        touchFailed = true
                        panRecognizer.isEnabled = false
                        panRecognizer.isEnabled = true
                    }
                    
                    if touchConfirmed {
                        if index != parentView.containerViews.count - 1 && !parentView.isCompact {
                            self.layer.zPosition = 1000
                        }
                    }
                }
                return
            }
            
            if touchFailed {
                return
            }
            
            var dx = location.x - startPanPoint.x
            
            if dx > 0 {
                dx = (sqrt(dx / 10 + 1) - 1) * 10 // Эффект "отскакивания" в правую сторону
            } else if !isRemovable {                // И, если карточку вообще нельзя убрать
                dx = -(sqrt(-dx / 10 + 1) - 1) * 10 // Эффект "отскакивания" в левую сторону
            }
            
            let ddx = dx - slideMovement
            
            slideMovement = dx
            
            layer.transform = CATransform3DTranslate(layer.transform, ddx, 0, 0)
            
        } else if sender.state == .ended {
            startPanPoint = nil
            slideMovement = 0
            
            if touchConfirmed {
                parentView.scrollLockFactor -= 1
            }
            
            if parentView.isFullScreen || !touchConfirmed {
                touchConfirmed = false
                touchFailed = false
                return
            }
            
            touchConfirmed = false
            touchFailed = false
            
            let velocity = sender.velocity(in: self)
            
            if isRemovable && velocity.x <= 25 && (velocity.x < -500 || slideMovement < -200) {
                closeTab()
            } else {
                parentView.restoreCardsLocations(animated: true)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + parentView.animationDuration) {
                    if self.index < self.superview!.subviews.count - 1 && !self.parentView.isCompact {
                        self.layer.zPosition = 0
                    }
                }
            }
            
        } else if sender.state == .failed || sender.state == .cancelled {
            startPanPoint = nil
            slideMovement = 0
            
            if touchConfirmed {
                parentView.scrollLockFactor -= 1
            }
            
            if parentView.isFullScreen || !touchConfirmed {
                touchConfirmed = false
                touchFailed = false
                return
            }
            
            touchConfirmed = false
            touchFailed = false
            
            parentView.restoreCardsLocations(animated: true)
        }
    }
    
    func closeTab(animated: Bool = true, completion: (() -> ())! = nil) {
        delegate?.tabWillClose?(editorTabView: self)
        
        panRecognizer.isEnabled = false
        //tapRecognizer.isEnabled = false
        
        if animated {
            UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseIn, animations: {
                self.layer.transform = CATransform3DTranslate(self.layer.transform, -self.parentView.bounds.width * 2, 0, 0)
                
            }, completion: {
                _ in
                self.removeFromSuperview()
            })
        } else {
            removeFromSuperview()
        }
        
        parentView.tabClosed(self, animated: animated)
    }
}
