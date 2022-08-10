import UIKit

@objc protocol EditorTabViewDelegate: AnyObject {
    @objc optional func tabWillClose(editorTabView: EditorTabView)
}

class EditorTabView: UIView, EditorTabGestureHandlerDelegate {
    
    override var keyCommands: [UIKeyCommand]? {
        if (parentView.containerViews.count < 2) {
            return []
        }

        return [
            UIKeyCommand(input: "[", modifierFlags: [.command, .shift], action: #selector(prevTab), discoverabilityTitle: localize("prevtab")),
            UIKeyCommand(input: "]", modifierFlags: [.command, .shift], action: #selector(nextTab), discoverabilityTitle: localize("nexttab")),
        ]
    }

    private func switchToTab(index: Int) {
        var index = index

        if (index == -1) {
            index = parentView.containerViews.count - 1
        }
        if (index >= parentView.containerViews.count) {
            index = 0
        }

        parentView.switchToTab(index: index)
    }

    @objc func prevTab() {
        switchToTab(index: index - 1)
    }

    @objc func nextTab() {
        switchToTab(index: index + 1)
    }
    
    weak var parentView: EditorSwitcherView!
    var index: Int = 0 {
        didSet {
            transformManager.zIndex = index
            layer.zPosition = CGFloat(index)
        }
    }
    
    var transformManager: TabViewTransformManager!
    var gestureHandler: EditorTabGestureHandler!
    var navController: TabNavigationController!
    var isRemovable: Bool {
        didSet {
            navController.titleContainer.closeButton.isHidden = !isRemovable
            gestureHandler.isTabRemovable = isRemovable
        }
    }
    
    weak var delegate: EditorTabViewDelegate?

    init(frame: CGRect, navigationController: TabNavigationController) {

        isRemovable = true

        super.init(frame: frame)

        isOpaque = true
        backgroundColor = .clear
        layer.backgroundColor = UIColor.clear.cgColor

        navController = navigationController
        navController.parentView = self
        navController.view.frame = bounds
        
        gestureHandler = EditorTabGestureHandler(view: self)
        gestureHandler.delegate = self
        
        transformManager = TabViewTransformManager()

        addSubview(navController.view)

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

    // TODO: Rewrite

    func focused(byShortcut: Bool = false) {
        isEditorFocused = true
        if window != nil {
            AppDelegate.updateSceneTitle(for: window!)
        }

        let controller = navController.editorViewController

        if let controller = controller as? FileEditor {
            controller.editor?.didFocus(byShortcut: byShortcut)
        }
        
        setInteractionEnabled(true)
        gestureHandler.enabled = false

        navController.switchToDefault(animated: false)
        navController.titleContainer.closeButton.isHidden = !isRemovable
        navController.titleContainer.becomeRegular()
    }

    func blurred() {
        isEditorFocused = false
        let controller = navController.editorViewController

        if let controller = controller as? FileEditor {
            controller.editor?.didBlur()
        }
        
        setInteractionEnabled(false)
        gestureHandler.enabled = true

        navController.switchToCompact(animated: false)
        navController.titleContainer.becomeCompact()
    }

    func setInteractionEnabled(_ enabled: Bool) {
        for view in navController.view.subviews {
            if view is TabTitleContainerView {
                continue
            }

            view.isUserInteractionEnabled = enabled
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navController.view.frame = bounds
    }

    // TODO

    /* @objc func handleZoom(_ sender: UIPinchGestureRecognizer) {
        if(sender.scale > 1) {
            sender.isEnabled = false
            sender.isEnabled = true
            return
        }
    }*/

    internal var viewsIsAppeared = false

    internal func viewsDisappeared() {
        guard viewsIsAppeared else {
            return
        }
        viewsIsAppeared = false

        navController.didMove(toParent: nil)
        navController.hideView()
    }

    internal func viewsAppeared() {
        guard !viewsIsAppeared else {
            return
        }
        viewsIsAppeared = true

        navController.didMove(toParent: parentView.parentViewController)
        navController.presentView()
    }
    
    func tabPressed(editorTabGesture: EditorTabGestureHandler, at position: CGPoint) {
        let buttonFrame = navController.titleContainer.closeButton.frame

        let buttonSize = buttonFrame.width + buttonFrame.origin.x * 2

        if position.x < buttonSize && position.y < buttonSize && isRemovable {
            closeTab()
            return
        }

        DispatchQueue.main.async { [self] in
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
    
    func tabHighlighted(editorTabGesture: EditorTabGestureHandler) {
        UIView.animate(withDuration: 0.4) {
            self.layer.transform = CATransform3DScale(self.layer.transform, 1.02, 1.02, 1)
        }
    }
    
    func tabUnHighlighted(editorTabGesture: EditorTabGestureHandler) {
        UIView.animate(withDuration: 0.2) {
            self.layer.transform = CATransform3DIdentity
        }
    }
    
    func tabDidSlide(_ gestureHandler: EditorTabGestureHandler) {
        transformManager.slideOffset = gestureHandler.slideMovement
    }
    
    func tabWillSlide(_ gestureHandler: EditorTabGestureHandler) {
        parentView.scrollLockFactor += 1
    }
    
    func tabDidEndSlide(_ gestureHandler: EditorTabGestureHandler) {
        parentView.scrollLockFactor -= 1
        let velocity = gestureHandler.slideVelocity
        let movement = gestureHandler.slideMovement
        
        if isRemovable && velocity <= 25 && (velocity < -500 || movement < -200) {
            closeTab()
        } else {
            transformManager.slideOffset = 0
        }
    }

    func closeTab(animated: Bool = true, completion: (() -> ())! = nil) {
        delegate?.tabWillClose?(editorTabView: self)

        gestureHandler.enabled = false

        removeFromSuperview()

        parentView.tabClosed(self, animated: animated)
    }
}
