import UIKit

class EditorSwitcherView: UIView, UIScrollViewDelegate {

    var animationDuration: TimeInterval = 0.5

    var containerViews = [EditorTabView]()

    var scrollView: UIScrollView!
    var zoomContainer: UIView!
    var zoomContainerHeightConstraint: NSLayoutConstraint!
    var zoomContainerWidthConstraint: NSLayoutConstraint!
    var preferredCornerRadius: CGFloat = 5.0
    var presentedView: EditorTabView!
    weak var lastOpenedView: EditorTabView!

    var isFullScreen = false
    
    var layout3d = EditorSwitcher3DLayout()
    var layoutFlat = EditorSwitcherFlatLayout()
    
    private var savedContentOffsetY: CGFloat! = nil

    var hasPrimaryTab: Bool {
        get {
            false
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        standardInitialize()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)!
        standardInitialize()
    }
    
    private func setPresentedView(presentedView: EditorTabView!) {
        if presentedView != self.presentedView {
            self.presentedView?.blurred()
            presentedView?.focused()
        }
        
        if presentedView != nil {
            if !hasPrimaryTab || presentedView.index != 0 {
                lastOpenedView = presentedView
            }
        }
        
        if presentedView == nil {
            scrollView.isScrollEnabled = presentedView == nil
        }
        
        self.presentedView = presentedView
    }

//    private func animatePath(layer: CALayer, oldPath: CGPath, newPath: CGPath, duration: CFTimeInterval, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut) {
//        let animation = CABasicAnimation(keyPath: "path")
//
//        let maskLayer = CAShapeLayer()
//
//        animation.fromValue = oldPath
//        animation.toValue = newPath
//        animation.duration = duration
//        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)
//
//        maskLayer.add(animation, forKey: nil)
//
//        CATransaction.begin()
//        CATransaction.setDisableActions(true)
//        maskLayer.path = newPath
//        CATransaction.commit()
//
//        layer.mask = maskLayer
//    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        restoreCardsLocations()
    }

    private func updateScrollViewContentSize() {

        if isCompact {
            scrollView.contentSize = layout3d.scrollViewContentSize()
            scrollView.minimumZoomScale = layout3d.scrollViewMinZoomScale()
        } else {
            scrollView.minimumZoomScale = layoutFlat.scrollViewMinZoomScale()
            scrollView.contentSize = layoutFlat.scrollViewContentSize()
        }

        zoomContainerWidthConstraint.constant = scrollView.contentSize.width / scrollView.minimumZoomScale
        zoomContainerHeightConstraint.constant = scrollView.contentSize.height / scrollView.minimumZoomScale
    }

    private func standardInitialize() {
        layout3d.switcher = self
        layoutFlat.switcher = self
        
        scrollView = UIScrollView(frame: bounds)
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isUserInteractionEnabled = true
        scrollView.isScrollEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        addSubview(scrollView)

        topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        leftAnchor.constraint(equalTo: scrollView.leftAnchor).isActive = true
        rightAnchor.constraint(equalTo: scrollView.rightAnchor).isActive = true

        zoomContainer = UIView()
        zoomContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(zoomContainer)

        scrollView.leftAnchor.constraint(equalTo: zoomContainer.leftAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: zoomContainer.rightAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: zoomContainer.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: zoomContainer.bottomAnchor).isActive = true
        zoomContainerHeightConstraint = zoomContainer.heightAnchor.constraint(equalToConstant: 0)
        zoomContainerWidthConstraint = zoomContainer.widthAnchor.constraint(equalToConstant: 0)

        zoomContainerHeightConstraint.isActive = true
        zoomContainerWidthConstraint.isActive = true
    }

    final func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }

    final func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        zoomContainer
    }

//    private func animate(transform: CATransform3D, view: UIView, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut) {
//        let basicAnim = CABasicAnimation(keyPath: #keyPath(CALayer.transform))
//
//        basicAnim.fromValue = view.layer.transform
//
//        basicAnim.toValue = transform
//        basicAnim.duration = animationDuration
//        basicAnim.timingFunction = CAMediaTimingFunction(name: timingFunction)
//
//        view.layer.add(basicAnim, forKey: nil)
//
//        CATransaction.setDisableActions(true)
//        view.layer.transform = transform
//        CATransaction.setDisableActions(false)
//    }

    /// Indicating whether interaction with the switcher is blocked. (e.g. during animation)
    internal var locked: Bool = false

    /// Optimized synchronous function that adds tabs to the switcher without animating anything.
    func addContainerViewsSilently(_ views: [EditorTabView]) {

        for view in views {
            view.backgroundColor = .clear
            view.index = containerViews.count
            view.parentView = self
            view.layer.anchorPoint = CGPoint(x: 0.5, y: isCompact ? 0 : 0.5)
            view.navController.view.layer.masksToBounds = true

            zoomContainer.addSubview(view)
            containerViews.append(view)

            if isFullScreen {
                view.isHidden = true
            }
        }

        // Update visible/invisible views
        scrollViewDidScroll(scrollView)
        restoreCardsLocations()
    }

    func addContainerView(_ view: EditorTabView, animated: Bool = true, force: Bool = false, completion: (() -> ())? = nil) {

        if locked && !force {
            return
        }

        if isFullScreen {
            animateOut(animated: false, force: true, completion: {
                self.addContainerView(view, animated: animated, force: true, completion: completion)
            })
            return
        }

        view.layer.anchorPoint = CGPoint(x: 0.5, y: isCompact ? 0 : 0.5)
        view.backgroundColor = .clear
        view.index = containerViews.count
        view.parentView = self

        zoomContainer.addSubview(view)
        containerViews.append(view)

        restoreCardsLocations()

        completion?()
    }

    public var scrollLockFactor = 0 {
        didSet {
            scrollView.panGestureRecognizer.isEnabled = scrollLockFactor == 0
        }
    }

    func tabClosed(_ closedTab: EditorTabView, animated: Bool) {
        closedTab.superview?.bringSubviewToFront(closedTab)
        containerViews.remove(at: closedTab.index)
        restoreIndexingOrder()
        restoreCardsLocations()

        if containerViews.count == 1 && hasPrimaryTab && presentedView == nil {
            animateIn(animated: animated, view: containerViews.first!)
        }
    }

    func animateOut(animated: Bool = true, force: Bool = false, completion: (() -> ())! = nil) {

        if locked && !force {
            return
        }

        if !isFullScreen {
            return
        }
        
        isFullScreen = false

        setPresentedView(presentedView: nil)
        
        restoreCardsLocations()
        
        scrollView.setZoomScale(self.scrollView.minimumZoomScale, animated: false)
        
        scrollViewDidScroll(scrollView)

        completion?()
    }

    final func switchToTab(index: Int) {
        guard isFullScreen else {
            return
        }

        let prevView = presentedView!
        let newView = containerViews[index]

        prevView.isHidden = true
        prevView.viewsDisappeared()

        newView.isHidden = false
        newView.viewsAppeared()

        setPresentedView(presentedView: nil)

        layoutSubviews()
    }

    final func scrollViewDidScroll(_ scrollView: UIScrollView) {

        if isFullScreen {
            if savedContentOffsetY != nil {
                scrollView.contentOffset.y = savedContentOffsetY
            }
            return
        }

        let zoomScale = scrollView.zoomScale
        let contentOffset = scrollView.contentOffset.y

        for view in containerViews {

            let maxY = (view.frame.maxY - contentOffset) * zoomScale
            let minY = (view.frame.minY - contentOffset) * zoomScale

            let oldIsHidden = view.isHidden

            view.isHidden = maxY < 0 || minY > frame.height

            if oldIsHidden != view.isHidden {
                if view.isHidden {
                    view.viewsDisappeared()
                } else {
                    view.viewsAppeared()
                }
            }

            if view.isHidden {
                continue
            }

            view.layer.transform = view.transformManager.getTransform()
        }
    }

    var isCompact: Bool {
        get {
            return false
        }
    }
    
    var maxContentOffsetY: CGFloat {
        let contentHeight = scrollView.contentSize.height
        let selfHeight = bounds.height
        return max(0, contentHeight - selfHeight)
    }

    var contentOffsetY: CGFloat {
        let contentOffsetY = scrollView.contentOffset.y

        return max(min(maxContentOffsetY, contentOffsetY), 0)
    }

    private func clearShadow(view: UIView) {
        view.layer.shadowPath = nil
        view.layer.shadowColor = nil
        view.layer.shadowRadius = 0
        view.layer.shadowOpacity = 0
    }

    private func setupShadow(view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowPath = UIBezierPath(rect: bounds).cgPath
        view.layer.shadowRadius = 20.0
    }

//    private func animateCornerRadius(layer: CALayer, from: CGFloat, to: CGFloat) {
//        let animation = CABasicAnimation(keyPath: "cornerRadius")
//        animation.fromValue = from
//        animation.toValue = to
//        animation.duration = animationDuration
//        layer.add(animation, forKey: "cornerRadius")
//        layer.cornerRadius = to
//    }

    private func getMainViewHeight() -> CGFloat {
        guard isCompact && hasPrimaryTab else {
            fatalError()
        }

        if (containerViews.count == 1) {
            return bounds.height
        } else if (containerViews.count < 4) {
            return bounds.height - 25 - CGFloat(containerViews.count * 5)
        } else {
            return bounds.height - 45
        }
    }

    func animateBottomViewOut() {
        guard !locked else {
            return
        }
        guard isFullScreen else {
            return
        }
        guard hasPrimaryTab else {
            return
        }
        guard containerViews.count == 2 else {
            return
        }
        guard presentedView.index == 1 else {
            return
        }

        let mainView = containerViews[0]

        mainView.isHidden = false
        mainView.viewsAppeared()
        
        setPresentedView(presentedView: mainView)

        restoreCardsLocations()
    }

    /// Animates entering to the only tab, from the bottom of the screen.
    func animateBottomViewIn() {
        guard !locked else {
            return
        }
        guard isFullScreen else {
            return
        }
        guard hasPrimaryTab else {
            return
        }
        guard containerViews.count == 2 else {
            return
        }
        guard presentedView.index == 0 else {
            return
        }

        let bottomView = containerViews[1]

        bottomView.viewsAppeared()
        bottomView.isHidden = false

        zoomContainer.bringSubviewToFront(bottomView)
    
        let mainView = presentedView!
        setPresentedView(presentedView: bottomView)
        
        mainView.navController.view.layer.cornerRadius = 0
        mainView.navController.view.layer.mask = nil
        bottomView.navController.view.layer.mask = nil
        mainView.isHidden = true
        mainView.viewsDisappeared()
        
        restoreCardsLocations()
    }

    /// Opens a specific tab with animation
    func animateIn(animated: Bool = true, force: Bool = false, view: EditorTabView, completion: (() -> ())? = nil) {

        if locked && !force {
            return
        }

        if isFullScreen && !force {
            return
        }
        isFullScreen = true

        let contentOffsetY = contentOffsetY
        savedContentOffsetY = self.contentOffsetY

        setPresentedView(presentedView: view)
        scrollView.contentOffset.y = contentOffsetY

        restoreCardsLocations()

        completion?()
    }

    /// Restores the numbering of cards. Must be called if list of open editors was changed.
    /// Call only when `presentedView == nil`
    func restoreIndexingOrder() {
        for i in 0..<containerViews.count {
            let view = containerViews[i]
            view.index = i
        }
    }

    final func restoreCardsLocations(animated: Bool = true) {

        layout3d.update()
        layoutFlat.update()
        savedContentOffsetY = nil
        updateScrollViewContentSize()
        
        if isCompact {

            let count = containerViews.count

            for i in 0..<count {
                let view = containerViews[i]
                
                view.layer.anchorPoint = CGPoint(x: 0.5, y: 0)
                view.frame = layout3d.frameFor(editorView: view)
                layout3d.updateTransformFor(editorView: view)
                view.layer.transform = view.transformManager.getTransform()
            }

            scrollView.minimumZoomScale = 1
            scrollView.zoomScale = 1
        } else {

            // 2D layout case

            for i in 0..<containerViews.count {
                let view = containerViews[i]

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                view.frame = layoutFlat.frameFor(editorView: view)
                layoutFlat.updateTransformFor(editorView: view)
                view.layer.transform = view.transformManager.getTransform()
                CATransaction.commit()
            }

            if isFullScreen {
                scrollView.contentOffset = presentedView.frame.origin
            } else {
                scrollView.zoomScale = scrollView.minimumZoomScale
            }
        }
        savedContentOffsetY = contentOffsetY
    }

    deinit {
        for view in containerViews {
            let editor = view.navController?.editorViewController
            (editor as? FileEditor)?.editor?.closeEditor()
        }
    }
}



