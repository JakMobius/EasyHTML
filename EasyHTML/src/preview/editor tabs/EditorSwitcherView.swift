import UIKit

class EditorSwitcherView: UIView, UIScrollViewDelegate {

    var animationDuration: TimeInterval = 0.5

    var containerViews = [EditorTabView]()

    var scrollView: UIScrollView!
    var zoomContainer: UIView!
    var zoomContainerHeightConstraint: NSLayoutConstraint!
    var zoomContainerWidthConstraint: NSLayoutConstraint!
    var preferredCornerRadius: CGFloat = 5.0
    var presentedView: EditorTabView! {
        didSet {
            if presentedView != nil && (!hasPrimaryTab || presentedView.index != 0) {
                lastOpenedView = presentedView
            }
            if #available(iOS 13.0, *) {

            }
        }
    }
    weak var lastOpenedView: EditorTabView!

    var isFullScreen = false

    // 3D layout variables

    let angle: CGFloat = 40.0
    let scaleOut: CGFloat = 0.95
    var switcherViewPadding: CGFloat = 100

    // 2D layout variables

    private var blocksInLine: CGFloat = 0
    private var maxBlocksInLine: CGFloat = 0
    private var paddedBlockHeight: CGFloat = 0
    private var paddedBlockWidth: CGFloat = 0
    private let verticalPadding: CGFloat = 50
    private let horizontalPadding: CGFloat = 50
    private let minBlockWidth: CGFloat = 150
    private let zIndexModifier: CGFloat = 100
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

    private func getFrameForItem(at index: Int) -> CGRect {

        if isCompact {

            if hasPrimaryTab && index == 0 && containerViews.count > 1 {
                return CGRect(x: 0.0,
                        y: CGFloat(index) * switcherViewPadding + 50,
                        width: frame.size.width,
                        height: getMainViewHeight() - insets.bottom)
            }

            return CGRect(x: 0.0,
                    y: CGFloat(index) * switcherViewPadding + 50,
                    width: frame.size.width,
                    height: frame.size.height)
        } else {

            let x = index % Int(blocksInLine)
            let y = index / Int(blocksInLine)

            let realX = CGFloat(x) * paddedBlockWidth + horizontalPadding
            let realY = CGFloat(y) * paddedBlockHeight + verticalPadding

            return CGRect(x: realX, y: realY, width: bounds.width, height: bounds.height)
        }
    }

    private func animatePath(layer: CALayer, oldPath: CGPath, newPath: CGPath, duration: CFTimeInterval, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut) {
        let animation = CABasicAnimation(keyPath: "path")

        let maskLayer = CAShapeLayer()

        animation.fromValue = oldPath
        animation.toValue = newPath
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)

        maskLayer.add(animation, forKey: nil)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.path = newPath
        CATransaction.commit()

        layer.mask = maskLayer
    }

    override func layoutSubviews() {
        updateLayoutSpecificConstants()

        super.layoutSubviews()

        let animation = layer.animation(forKey: "bounds.size")

        let rotationAnimationDuration = animation?.duration ?? 0

        let doesHavePrimaryTab = hasPrimaryTab

        savedContentOffsetY = nil

        if isCompact {

            updateScrollViewContentSize()

            let contentOffsetY = contentOffsetY

            let count = containerViews.count

            for i in 0..<count {
                let view = containerViews[i]
                var transform: CATransform3D

                view.layer.anchorPoint = CGPoint(x: 0.5, y: 0)

                if isFullScreen {

                    transform = view.layer.transform

                } else {

                    transform = getTransform(view: view, translatedToY: 0, isScale: true, isRotate: true)
                }

                if !isFullScreen || view.index == presentedView.index {
                    view.layer.transform = CATransform3DIdentity

                    view.frame = getFrameForItem(at: i)

                    if view == presentedView {
                        let translationY = view.frame.origin.y - contentOffsetY

                        view.layer.transform = CATransform3DMakeTranslation(0, -translationY, CGFloat(zIndexModifier * CGFloat(view.index)))
                    } else {
                        view.layer.transform = transform
                    }

                    // This fixes UINavigationBar size not being updated on screen rotationon iOS < 11
                    view.navController.fixResizeIssue()
                    view.navController.view.cornerRadius = 0

                    // This helps to remove rounded corners when layout traits change
                    view.navController.view.layer.mask = nil
                }

                if doesHavePrimaryTab && isFullScreen && presentedView.index == 0 {
                    if i == 0 {
                        if count > 1 {
                            let primaryTabBounds = CGRect(
                                    x: 0,
                                    y: 0,
                                    width: bounds.width,
                                    height: getMainViewHeight() - insets.bottom
                            )

                            let path = CAShapeLayer.getRoundedRectPath(frame: primaryTabBounds, roundingCorners: [.bottomLeft, .bottomRight], withRadius: preferredCornerRadius)

                            // Animate corner mask

                            if rotationAnimationDuration != 0 && view.navController.view.layer.mask != nil {
                                let startPath = (view.navController.view.layer.mask as! CAShapeLayer).path!

                                animatePath(layer: view.navController.view.layer, oldPath: startPath, newPath: path, duration: rotationAnimationDuration)
                            } else {
                                let maskLayer = CAShapeLayer()
                                maskLayer.path = path
                                view.navController.view.layer.mask = maskLayer
                            }

                        } else {
                            view.navController.view.layer.mask = nil
                        }

                        // The current window should not have a shadow.

                        // setupShadow(view: view)

                    } else if i < 4 {

                        // Update frames on bottom views.
                        view.isHidden = false
                        view.layer.transform = CATransform3DIdentity

                        view.frame = getFrameForItem(at: view.index)

                        if (!view.navController.titleContainer.isCompact) {
                            view.navController.titleContainer.becomeCompact()
                            view.setGestureRecognisersEnabled(true)
                        }

                        // Similar to the case with the main tab.
                        // There are rounded corners on the bottom views,
                        // they also need to be updated with animation.

                        let path = CAShapeLayer.getRoundedRectPath(frame: bounds, roundingCorners: [.topLeft, .topRight], withRadius: preferredCornerRadius)

                        if rotationAnimationDuration != 0 && view.navController.view.layer.mask != nil {

                            let startPath = (view.navController.view.layer.mask as! CAShapeLayer).path!

                            animatePath(layer: view.navController.view.layer, oldPath: startPath, newPath: path, duration: rotationAnimationDuration)
                        } else {
                            let maskLayer = CAShapeLayer()
                            maskLayer.path = path
                            view.navController.view.layer.mask = maskLayer
                        }

                        view.layer.transform = getTransformBottomView(index: i)

                        // Update shadow sizes

                        setupShadow(view: view)
                    } else {
                        view.navController.view.layer.mask = nil
                    }
                } else {
                    view.navController.view.layer.mask = nil
                }

                if !isFullScreen {
                    for i in 0..<count {
                        let view = containerViews[i]

                        setupShadow(view: view)
                    }
                }
            }

            scrollView.minimumZoomScale = 1
            scrollView.zoomScale = 1
        } else {

            // 2D layout case

            for i in 0..<containerViews.count {
                let view = containerViews[i]

                view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

                view.layer.transform = CATransform3DIdentity

                // Only update current window frame, when in fullscreen mode
                if !isFullScreen || view.index == presentedView.index {
                    view.frame = getFrameForItem(at: i)
                }

                if !isFullScreen {

                    // Shadows should take place only when in not-fullscreen mode

                    let animation = CABasicAnimation(keyPath: "shadowPath")

                    animation.fromValue = view.layer.shadowPath
                    animation.toValue = UIBezierPath(rect: bounds).cgPath
                    animation.duration = rotationAnimationDuration
                    animation.timingFunction = CAMediaTimingFunction(name: .linear)

                    view.layer.add(animation, forKey: nil)

                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    setupShadow(view: view)
                    CATransaction.commit()
                }

                view.navController.view.layer.mask = nil
            }

            updateScrollViewContentSize()

            if isFullScreen {
                scrollView.contentOffset = presentedView.frame.origin
            } else {
                scrollView.zoomScale = scrollView.minimumZoomScale
            }
        }
        savedContentOffsetY = contentOffsetY
    }

    private func updateLayoutSpecificConstants() {
        let paddedBoundsWidth = bounds.width - horizontalPadding
        let paddedMinBlockWidth = minBlockWidth + horizontalPadding
        paddedBlockWidth = bounds.width + horizontalPadding
        paddedBlockHeight = bounds.height + verticalPadding

        maxBlocksInLine = min(floor(paddedBoundsWidth / paddedMinBlockWidth), 3)

        blocksInLine = max(1, min(maxBlocksInLine, CGFloat(containerViews.count)))

        switcherViewPadding = max(bounds.height / 4, 100)
    }

    private func updateScrollViewContentSize() {

        if isCompact {
            scrollView.contentSize.width = bounds.width
            scrollView.contentSize.height = bounds.height + switcherViewPadding * CGFloat(containerViews.count - 2)
            scrollView.minimumZoomScale = 1.0
        } else {

            let realBlockWidth = bounds.width + horizontalPadding
            let realBlockHeight = bounds.height + verticalPadding

            let scrollViewContentSizeWidth = (realBlockWidth * blocksInLine + horizontalPadding)
            var scrollViewContentSizeHeight: CGFloat

            scrollView.minimumZoomScale = bounds.width / scrollViewContentSizeWidth

            let height1 = bounds.height

            if blocksInLine <= 1 {
                scrollViewContentSizeHeight = height1
            } else {
                var height2 = realBlockHeight * ceil(CGFloat(containerViews.count) / blocksInLine) * scrollView.minimumZoomScale

                height2 += 2 * verticalPadding

                scrollViewContentSizeHeight = max(height1, height2)
            }

            scrollView.contentSize = CGSize(
                    width: bounds.width,
                    height: scrollViewContentSizeHeight
            )
        }

        zoomContainerWidthConstraint.constant = scrollView.contentSize.width / scrollView.minimumZoomScale
        zoomContainerHeightConstraint.constant = (scrollView.contentSize.height + switcherViewPadding) / scrollView.minimumZoomScale
    }

    private func standardInitialize() {
        scrollView = UIScrollView(frame: bounds)
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
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

    private func radians(degrees: CGFloat) -> CGFloat {
        degrees * CGFloat.pi / 180.0
    }

    final func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        zoomContainer
    }

    private func animate(transform: CATransform3D, view: UIView, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut) {
        let basicAnim = CABasicAnimation(keyPath: #keyPath(CALayer.transform))

        basicAnim.fromValue = view.layer.transform

        basicAnim.toValue = transform
        basicAnim.duration = animationDuration
        basicAnim.timingFunction = CAMediaTimingFunction(name: timingFunction)

        view.layer.add(basicAnim, forKey: nil)

        CATransaction.setDisableActions(true)
        view.layer.transform = transform
        CATransaction.setDisableActions(false)
    }

    /// Indicating whether interaction with the switcher is blocked. (e.g. during animation)
    internal var locked: Bool = false

    /// Optimized synchronous function that adds tabs to the switcher without animating anything.
    func addContainerViewsSilently(_ views: [EditorTabView]) {

        let shouldUseBottomAnimation = presentedView.index == 0 && views.count < 4 && hasPrimaryTab

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

        for view in views {

            if isCompact {

                if shouldUseBottomAnimation {
                    view.frame = getFrameForItem(at: view.index)
                    view.navController.titleContainer.becomeCompact()
                    view.layer.transform = getTransformBottomView(index: view.index)
                } else {
                    let translation = isFullScreen ? 0 : bounds.height

                    view.layer.transform = getTransform(view: view, translatedToY: translation, isScale: isFullScreen, isRotate: isFullScreen)
                }
            }
        }
    }

    func addContainerView(_ view: EditorTabView, animated: Bool = true, force: Bool = false, completion: (() -> ())? = nil) {

        if locked && !force {
            return
        }

        if isFullScreen {

            if animated {
                locked = true
            }

            // The 'force' flag not only bypasses all locks, it also prevents
            // 'locked' field from being updated. The absence of this flag
            // may lead to race of animations, and bring controllers into an
            // inconsistent state.

            animateOut(animated: animated, force: true, completion: {
                self.addContainerView(view, animated: animated, force: true, completion: completion)
            })
            return
        }

        var animated = animated

        if !isCompact && animated && blocksInLine < maxBlocksInLine && !containerViews.isEmpty {
            animated = false
        }

        if animated && !force {
            locked = true
        }

        view.layer.anchorPoint = CGPoint(x: 0.5, y: isCompact ? 0 : 0.5)
        view.backgroundColor = .clear
        view.index = containerViews.count
        view.parentView = self

        zoomContainer.addSubview(view)
        containerViews.append(view)

        updateLayoutSpecificConstants()
        updateScrollViewContentSize()

        let maxContentOffsetY = maxContentOffsetY
        let oldContentOffsetY = scrollView.contentOffset.y

        view.frame = getFrameForItem(at: view.index)

        // When in 3D mode, scroll to the very bottom
        // of the scroll view, so the parallax effect
        // is computed correctly.

        if isCompact {
            scrollView.contentOffset.y = maxContentOffsetY
        }

        let newTransform = getTransform(
                view: view,
                translatedToY: 0,
                isScale: true,
                isRotate: true
        )

        // Scroll back to original position

        if isCompact {
            scrollView.contentOffset.y = oldContentOffsetY
        }

        // Scroll to the very bottom, but with animation now.

        scrollView.setContentOffset(CGPoint(x: 0, y: maxContentOffsetY), animated: animated)

        if isCompact {
            if animated {

                // Animation of the card, flying out from below

                view.layer.transform = getTransform(
                        view: view,
                        translatedToY: bounds.height,
                        isScale: true,
                        isRotate: true
                )

                animate(transform: newTransform, view: view)
            } else {
                view.layer.transform = newTransform
            }
        } else {
            if animated {

                // Animation of the card, scaling in from the singularity.

                view.transform = CGAffineTransform(scaleX: 0, y: 0)
                UIView.animate(withDuration: animated ? animationDuration : 0, delay: 0, options: .curveEaseInOut, animations: {
//                    self.scrollView.zoomScale = self.scrollView.minimumZoomScale
                    view.transform = .identity
                })
            }
        }

        view.setInteractionEnabled(false)
        view.navController.view.layer.masksToBounds = true
        view.navController.view.layer.cornerRadius = preferredCornerRadius
        view.viewsAppeared()

        setupShadow(view: view)

        // TODO: crutch

        let delay = animated ? animationDuration : 0.07

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.locked = false
            completion?()
        }
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
        if (presentedView == nil) {
            restoreCardsLocations(animated: animated)
        } else if animated {
            if (containerViews.count >= 4) {
                layoutSubviews()
            } else {
                let oldPath = (presentedView.navController.view.layer.mask as? CAShapeLayer)?.path
                let oldPresentedViewFrame = presentedView.frame
                UIView.setAnimationsEnabled(false)
                layoutSubviews()
                UIView.setAnimationsEnabled(true)
                let newPath = (presentedView.navController.view.layer.mask as? CAShapeLayer)?.path
                let newPresentedViewFrame = presentedView.frame
                presentedView.frame = oldPresentedViewFrame

                if let oldPath = oldPath, let newPath = newPath {
                    animatePath(layer: presentedView.navController.view.layer, oldPath: oldPath, newPath: newPath, duration: animationDuration, timingFunction: .easeOut)
                }

                UIView.animate(withDuration: animationDuration) {
                    self.presentedView.frame = newPresentedViewFrame
                    self.presentedView.layoutIfNeeded()
                }
            }
        } else {
            layoutSubviews()
        }


        if containerViews.count == 1 && hasPrimaryTab && presentedView == nil {
            animateIn(animated: animated, view: containerViews.first!)
        }

        // Within the tab changer code, 'animated' flag is set to true only if the tab has been thrown out
        // by the user. If it was closed during controller swapping from the switcher to the the switcher,
        // then animated is set to false. Although it's not obvious from the variable name, here we'll use
        // this flag to to understand that we have to create a NoEditorController.

        if containerViews.isEmpty {

            // There is a funny bug: When you flip the screen on iPhones with a large screen,
            // the swap works so that when you flip the screen an empty editor is created,
            // although it is not needed here. That's why the whole creation block is only executed
            // with the animated flag, because this variable is false only when we swap controllers.
            // The swapper will create an empty editor itself if it's needed

            if animated {

                let emptyEditor = NoEditorPreviewController.present(animated: isCompact, on: self)

                // The normal animation of empty editor creation works a bit strange in 2D-layout,
                // so there is a separate one.

                if !isCompact {
                    locked = true

                    emptyEditor.tabView.transform = CGAffineTransform(scaleX: 0, y: 0)

                    UIView.animate(withDuration: animationDuration, animations: {
                        emptyEditor.tabView.transform = .identity
                    }) { _ in
                        self.locked = false
                    }
                }
            }
        }
    }

    func getTransform(view: EditorTabView, translatedToY: CGFloat, isScale: Bool, isRotate: Bool) -> CATransform3D {

        if isCompact {

            let scrollTop = contentOffsetY

            let blockTop = (CGFloat(view.index) * switcherViewPadding) - scrollTop

            var transform = CATransform3DMakeTranslation(0, 0, CGFloat(zIndexModifier * CGFloat(view.index)))

            if isRotate || isScale {
                transform.m34 = -0.0005
            }

            if translatedToY != 0.0 {
                transform = CATransform3DTranslate(transform, 0.0, translatedToY, 0.0)
            }

            if isRotate {
                let rotation = -radians(degrees: angle + blockTop / bounds.height * 40)
                transform = CATransform3DRotate(transform, rotation, 1.0, 0.0, 0.0)
            }

            if isScale {

                if UIDevice.current.hasAnEyebrow && UIApplication.shared.statusBarOrientation.isLandscape {

                    var scale = scaleOut

                    // The eyebrow height is 30px

                    scale *= ((bounds.width - 30) / bounds.width)

                    let dx: CGFloat = UIApplication.shared.statusBarOrientation == .landscapeLeft ? -15 : 15

                    transform = CATransform3DScale(transform, scale, scale, scale)
                    transform = CATransform3DTranslate(transform, dx, 0, 0)
                } else {
                    transform = CATransform3DScale(transform, scaleOut, scaleOut, scaleOut)
                }
            }

            if isRotate && isScale {

                if view.slideMovement != 0 {
                    transform = CATransform3DTranslate(transform, view.slideMovement, 0, 0)
                }

                let yPoint = CGFloat(view.index) * switcherViewPadding

                let offsetTop = yPoint - scrollView.contentOffset.y + 10

                if offsetTop < 0 {
                    let scale = 1 - (min(120, -offsetTop) / 2000)

                    transform = CATransform3DScale(transform, scale, scale, scale)
                }
            }

            return transform
        } else {

            return CATransform3DIdentity
        }
    }

    func animateOut(animated: Bool = true, force: Bool = false, completion: (() -> ())! = nil) {

        if locked && !force {
            return
        }

        if animated && !force {
            locked = true
        }

        if !isFullScreen {
            return
        }
        isFullScreen = false

        let presentedView = presentedView!

        presentedView.blurred()

        if presentedView.index == 0 {
            presentedView.superview?.insertSubview(presentedView, at: 0)
        }

        scrollView.isScrollEnabled = true

        self.presentedView = nil

        let scrollTop = contentOffsetY

        for view in containerViews {
            let viewtop = CGFloat(view.index) * switcherViewPadding - scrollTop
            let viewbottom = viewtop + bounds.height

            view.navController.view.layer.mask = nil
            view.isHidden = viewbottom < 0 || viewtop > frame.height

            if !view.isHidden {
                view.viewsAppeared()
            }
        }

        let firstIndex = getFirstVisibleIndex()

        func setupView(view: EditorTabView) {

            setupShadow(view: view)
            view.frame = getFrameForItem(at: view.index)

            view.setInteractionEnabled(false)
            view.setGestureRecognisersEnabled(true)

            // This fixes the glitch with a fraction of a second shadow at
            // the top of an open card from the card above it.

            if view.index == 0 && presentedView.index == 1 && isCompact && hasPrimaryTab && animated {

                view.layer.shadowOpacity = 0.0

                let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
                shadowAnimation.fromValue = 0.0
                shadowAnimation.toValue = 0.5
                shadowAnimation.duration = animationDuration / 2
                // Delay animation by half of its duration
                shadowAnimation.beginTime = CACurrentMediaTime() + shadowAnimation.duration
                shadowAnimation.isRemovedOnCompletion = false
                shadowAnimation.fillMode = .forwards
                view.layer.add(shadowAnimation, forKey: shadowAnimation.keyPath)
            }

            if view.navController.isFullScreen {
                view.navController.switchToCompact(animated: animated)
            }

            UIView.animate(withDuration: animated ? animationDuration : 0, animations: {
                view.navController.titleContainer.closeButton.isHidden = !view.isRemovable
                view.navController.titleContainer.becomeRegular()
                view.navController.viewDidLayoutSubviews()
            }, completion: nil)
        }

        if isCompact {

            for i in firstIndex..<containerViews.count {
                let view = containerViews[i]

                let oldTransform = view.layer.transform
                view.layer.transform = CATransform3DIdentity

                setupView(view: view)

                if !hasPrimaryTab || presentedView.index != 0 || i >= 4 {
                    if i > presentedView.index {
                        view.layer.transform = getTransform(view: view, translatedToY: bounds.size.height, isScale: true, isRotate: false)
                    } else if i < presentedView.index {
                        view.layer.transform = getTransform(view: view, translatedToY: -bounds.size.height, isScale: false, isRotate: false)
                    } else {
                        view.layer.transform = oldTransform
                    }
                } else {
                    view.layer.transform = oldTransform
                }

                let transform = getTransform(view: view, translatedToY: 0.0, isScale: true, isRotate: true)

                if i == 0 && UIDevice.current.hasAnEyebrow && hasPrimaryTab {

                    if animated {
                        let path1 = CAShapeLayer.getRoundedRectPath(size: view.bounds.size, lt: 40, rt: 40, lb: preferredCornerRadius, rb: preferredCornerRadius)
                        let path2 = CAShapeLayer.getRoundedRectPath(size: view.bounds.size, lt: preferredCornerRadius, rt: preferredCornerRadius, lb: preferredCornerRadius, rb: preferredCornerRadius)

                        animatePath(layer: view.navController.view.layer, oldPath: path1, newPath: path2, duration: animationDuration)
                    }

                }

                if animated && !view.isHidden {
                    animate(transform: transform, view: view)
                } else {
                    view.layer.transform = transform
                }

                if animated {
                    UIView.animate(withDuration: animationDuration, animations: view.navController.viewDidLayoutSubviews)
                } else {
                    view.navController.viewDidLayoutSubviews()
                }
            }
        } else {
            for i in firstIndex..<containerViews.count {
                let view = containerViews[i]

                setupView(view: view)
            }
            UIView.animate(withDuration: animated ? animationDuration : 0, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.9, options: [UIView.AnimationOptions.curveLinear], animations: {
                self.scrollView.setZoomScale(self.scrollView.minimumZoomScale, animated: animated)
            })
        }

        isUserInteractionEnabled = false

        for i in firstIndex..<containerViews.count {
            let view = containerViews[i]

            if animated && presentedView.index == i {
                if !hasPrimaryTab || !isCompact || i > 3 || presentedView.index != 0 {

                    let instance = PrimarySplitViewController.instance(for: self)!

                    if UIDevice.current.hasAnEyebrow {
                        let roundLeftCorners = !UIDevice.current.hasAnEyebrow || instance.displayMode == .primaryHidden

                        let endPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                                lt: preferredCornerRadius,
                                rt: preferredCornerRadius,
                                lb: preferredCornerRadius,
                                rb: preferredCornerRadius)
                        let startPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                                lt: roundLeftCorners ? 40 : 0.01,
                                rt: 40,
                                lb: roundLeftCorners ? 40 : 0.01,
                                rb: 40)

                        animatePath(layer: view.navController.view.layer,
                                oldPath: startPath,
                                newPath: endPath,
                                duration: animationDuration)

                        view.navController.view.cornerRadius = preferredCornerRadius
                    } else {
                        animateCornerRadius(layer: view.navController.view.layer, from: 0.01, to: preferredCornerRadius)
                    }


                    continue
                }
            }

            view.navController.view.layer.cornerRadius = preferredCornerRadius
        }

        func complete() {

            for view in containerViews {
                view.navController.view.layer.mask = nil
            }

            isUserInteractionEnabled = true
            scrollViewDidScroll(scrollView)

            if !force {
                locked = false
            }

            completion?()
        }

        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration, execute: complete)
        } else {
            complete()
        }
    }

    final func switchToTab(index: Int) {
        guard isFullScreen else {
            return
        }

        let prevView = presentedView!
        let newView = containerViews[index]

        prevView.isHidden = true
        prevView.blurred()
        prevView.viewsDisappeared()
        prevView.navController.switchToCompact(animated: false)
        prevView.setGestureRecognisersEnabled(true)
        prevView.setInteractionEnabled(false)

        newView.isHidden = false
        newView.navController.switchToDefault(animated: false)
        newView.setGestureRecognisersEnabled(false)
        newView.setInteractionEnabled(true)
        newView.viewsAppeared()
        newView.focused(byShortcut: true)

        presentedView = newView

        if isCompact {
            newView.transform = .identity
        }

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

            view.layer.transform = getTransform(view: view, translatedToY: 0, isScale: true, isRotate: true)

        }
    }

    var isCompact: Bool {
        get {
            maxBlocksInLine <= 1
        }
    }

    private func getFirstVisibleIndex() -> Int {
        if isCompact {

            let negativeOffset = (scrollView.contentOffset.y - bounds.height)

            if negativeOffset == 0 {
                return 0
            }

            if switcherViewPadding == 0 {
                return 0
            }

            return max(Int(negativeOffset / switcherViewPadding), 0)
        } else {
            return 0
        }
    }

    private var maxContentOffsetY: CGFloat {
        let contentHeight = scrollView.contentSize.height
        let selfHeight = bounds.height
        return max(0, contentHeight - selfHeight)
    }

    private var contentOffsetY: CGFloat {
        let contentOffsetY = scrollView.contentOffset.y

        return max(min(maxContentOffsetY, contentOffsetY), 0)
    }

    private var insets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return safeAreaInsets
        }
        return .zero
    }

    private func getTransformBottomView(index: Int) -> CATransform3D {

        let countOfAlwaysVisibleCards = min(containerViews.count - 1, 3)

        let view = containerViews[index]

        let oldTransform = view.layer.transform

        view.layer.transform = CATransform3DIdentity

        let top = view.frame.origin.y - contentOffsetY - bounds.height + 32 + insets.bottom

        var transform = getTransform(view: view, translatedToY: -top, isScale: false, isRotate: false)

        let deltaScale: CGFloat = 0.02

        let scale = 1 + CGFloat(index - countOfAlwaysVisibleCards) * deltaScale

        transform = CATransform3DScale(transform, scale, scale, 1)
        transform = CATransform3DTranslate(transform, 0, CGFloat(index - countOfAlwaysVisibleCards) * 5, 0)

        view.layer.transform = oldTransform

        view.navController.view.layer.mask =
                CAShapeLayer.getRoundedRectShape(
                        frame: view.bounds,
                        roundingCorners: [.topLeft, .topRight],
                        withRadius: preferredCornerRadius
                )

        return transform
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

    private func animateCornerRadius(layer: CALayer, from: CGFloat, to: CGFloat) {
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = animationDuration
        layer.add(animation, forKey: "cornerRadius")
        layer.cornerRadius = to
    }

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

        locked = true

        let bottomView = presentedView!

        bottomView.setInteractionEnabled(false)
        bottomView.blurred()

        let mainView = containerViews[0]

        mainView.isHidden = false
        mainView.viewsAppeared()
        mainView.navController.switchToDefault(animated: false)

        bottomView.navController.switchToCompact(animated: true)
        mainView.navController.titleContainer.becomeRegular()

        mainView.layer.transform = CATransform3DIdentity
        mainView.frame = getFrameForItem(at: 0)

        if UIDevice.current.hasAnEyebrow {
            let path1 = CAShapeLayer.getRoundedRectPath(size: mainView.bounds.size, lt: preferredCornerRadius, rt: preferredCornerRadius, lb: preferredCornerRadius, rb: preferredCornerRadius)
            let path2 = CAShapeLayer.getRoundedRectPath(size: mainView.bounds.size, lt: 40, rt: 40, lb: preferredCornerRadius, rb: preferredCornerRadius)

            animatePath(layer: mainView.navController.view.layer, oldPath: path1, newPath: path2, duration: animationDuration)
        } else {
            animateCornerRadius(layer: mainView.navController.view.layer, from: preferredCornerRadius, to: 0)
        }

        let topPosition = mainView.frame.origin.y - contentOffsetY
        let mainViewTransform = getTransform(view: mainView, translatedToY: -topPosition, isScale: false, isRotate: false)

        var startTransform = CATransform3DScale(mainViewTransform, 0.8, 0.8, 1)
        startTransform = CATransform3DTranslate(startTransform, 0, bounds.height * 0.1, 0)

        mainView.layer.transform = startTransform

        animate(transform: mainViewTransform, view: mainView, timingFunction: .easeInEaseOut)

        // The form has a rounding of 0.01, not 0, because there is a bug in
        // UIKit has a bug that makes the rounding animation does not work correctly
        // if you change it from zero to a non-zero value. Although Apple considers
        // this to be "correct behavior".

        let roundedCorners: UIRectCorner = [.topLeft, .topRight]
        let frame = presentedView.bounds

        let startPath = CAShapeLayer.getRoundedRectPath(frame: frame, roundingCorners: roundedCorners, withRadius: UIDevice.current.hasAnEyebrow ? 40 : 0.01)
        let endPath = CAShapeLayer.getRoundedRectPath(frame: frame, roundingCorners: roundedCorners, withRadius: preferredCornerRadius)

        animatePath(layer: presentedView.navController.view.layer, oldPath: startPath, newPath: endPath, duration: animationDuration)

        presentedView = mainView

        // Animate the slide of the bottom card

        let bottomViewTransform = CATransform3DTranslate(bottomView.layer.transform, 0, bounds.height - 32 - insets.bottom, 0)
        animate(transform: bottomViewTransform, view: bottomView, timingFunction: .easeInEaseOut)

        // Since CABasicAnimation has no completion method, we use DispatchQueueue to
        // organize all the finishing moments. We unlock the switcher for user
        // interaction, disable the shadows, and clear the mask of the shown card,
        // because we have already animated all the corner radii to zero.

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.locked = false
            self.clearShadow(view: mainView)
            if UIDevice.current.hasAnEyebrow {
                mainView.navController.view.layer.mask = CAShapeLayer.getRoundedRectShape(frame: mainView.bounds, roundingCorners: [.bottomLeft, .bottomRight], withRadius: self.preferredCornerRadius)
            }

            bottomView.viewsDisappeared()
        }

        // Update the navigation controller in the next tick so that it
        // realizes that he is at the top of the screen, so it gets under
        // the status bar. This has to be done asynchronously. Apparently,
        // it updates some of its variables at the end of the tick...

        DispatchQueue.main.async {
            mainView.frame.size.height = self.getMainViewHeight() - self.insets.bottom
            if !UIDevice.current.hasAnEyebrow {
                mainView.navController.view.layer.mask = CAShapeLayer.getRoundedRectShape(frame: mainView.bounds, roundingCorners: [.bottomLeft, .bottomRight], withRadius: self.preferredCornerRadius)
            }
            mainView.navController.view.layoutSubviews()
            //mainView.layoutSubviews()
        }

        mainView.setInteractionEnabled(true)
        mainView.setGestureRecognisersEnabled(false)

        bottomView.navController.titleContainer.becomeCompact()

        bottomView.setGestureRecognisersEnabled(true)

        // This fixes UINavigationBar size not being updated on screen rotation on iOS < 11
        mainView.navController.fixResizeIssue()
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

        locked = true

        presentedView.setInteractionEnabled(false)

        let bottomView = containerViews[1]

        bottomView.navController.switchToDefault()

        bottomView.setInteractionEnabled(true)
        bottomView.setGestureRecognisersEnabled(false)
        bottomView.viewsAppeared()

        // In case this tab was just added by addContainerViewsSilently method
        bottomView.isHidden = false

        let scale = 0.8;
        var transform = CATransform3DScale(presentedView.layer.transform, scale, scale, 1)

        // Take into account that the anchor point of the transformation is located at the top of the view

        transform = CATransform3DTranslate(transform, 0, presentedView.bounds.height * (1 - scale) / 2, 0)

        if UIDevice.current.hasAnEyebrow {
            let path1 = CAShapeLayer.getRoundedRectPath(size: presentedView.bounds.size, lt: 40, rt: 40, lb: preferredCornerRadius, rb: preferredCornerRadius)
            let path2 = CAShapeLayer.getRoundedRectPath(size: presentedView.bounds.size, lt: preferredCornerRadius, rt: preferredCornerRadius, lb: preferredCornerRadius, rb: preferredCornerRadius)

            animatePath(layer: presentedView.navController.view.layer, oldPath: path1, newPath: path2, duration: animationDuration)
        } else {
            animateCornerRadius(layer: presentedView.navController.view.layer, from: 0, to: preferredCornerRadius)
        }

        animate(transform: transform, view: presentedView, timingFunction: .easeInEaseOut)

        // Move back the currently shown card.
        // Since it should not have a from the shadow on it lower cards,
        // it is automatically moved to the foreground when it is shown.

        zoomContainer.bringSubviewToFront(bottomView)

        let oldTransform = bottomView.layer.transform
        bottomView.layer.transform = CATransform3DIdentity

        let topPosition = bottomView.frame.origin.y - contentOffsetY
        let bottomViewTransform = getTransform(view: bottomView, translatedToY: -topPosition, isScale: false, isRotate: false)
        bottomView.layer.transform = oldTransform

        let startShapeLayer = bottomView.navController.view.layer.mask as? CAShapeLayer

        // animateBottomViewIn can be called when the controller is not uninitialized yet, and so it
        // has no mask. In this case we don't animate the corner radius.

        if let startPath = startShapeLayer?.path {

            // The form has a rounding of 0.01, not 0, because there is a bug in
            // UIKit has a bug that makes the rounding animation does not work correctly
            // if you change it from zero to a non-zero value. Although Apple considers
            // this to be "correct behavior".

            let endPath = CAShapeLayer.getRoundedRectPath(frame: bottomView.bounds, roundingCorners: [.topLeft, .topRight], withRadius: UIDevice.current.hasAnEyebrow ? 40 : 0.01)

            animatePath(
                    layer: bottomView.navController.view.layer,
                    oldPath: startPath,
                    newPath: endPath,
                    duration: animationDuration
            )
        }

        let mainView = presentedView!
        presentedView = bottomView

        animate(transform: bottomViewTransform, view: bottomView, timingFunction: .easeInEaseOut)

        // Since CABasicAnimation has no completion method, we use DispatchQueueue to
        // organize all the finishing moments. We unlock the switcher for user
        // interaction, disable the shadows, and clear the mask of the shown card,
        // because we have already animated all the corner radii to zero.

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.locked = false
            self.clearShadow(view: bottomView)
            bottomView.navController.titleContainer.becomeRegular()
            mainView.navController.view.layer.cornerRadius = 0
            mainView.navController.view.layer.mask = nil
            bottomView.navController.view.layer.mask = nil
            mainView.isHidden = true
            mainView.viewsDisappeared()

            bottomView.focused()
        }

        // Update the navigation controller in the next tick so that it
        // realizes that he is at the top of the screen, so it gets under
        // the status bar. This has to be done asynchronously. Apparently,
        // it updates some of its variables at the end of the tick...

        bottomView.navController.view.setNeedsLayout()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let nb = bottomView.navController.navigationBar
            nb.layoutSubviews()
        }

        mainView.setInteractionEnabled(true)
        mainView.setGestureRecognisersEnabled(false)

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

        if animated && !force {
            locked = true
        }

        let contentOffsetY = contentOffsetY

        savedContentOffsetY = self.contentOffsetY

        presentedView = view

        //view.hideImage()

        scrollView.isScrollEnabled = false
        scrollView.contentOffset.y = contentOffsetY

        let doesHavePrimaryTab = hasPrimaryTab

        let firstIndex = getFirstVisibleIndex()
        view.setInteractionEnabled(true)

        if isCompact {

            // Animate the cards that are located lower than the opened one

            for i in firstIndex..<view.index {
                let eachView = containerViews[i]

                eachView.setGestureRecognisersEnabled(false)
                eachView.navController.view.layer.mask = nil

                if eachView.isHidden {
                    continue
                }

                let transform = getTransform(view: eachView, translatedToY: -bounds.size.height, isScale: true, isRotate: false)

                if animated {
                    animate(transform: transform, view: eachView)
                } else {
                    eachView.layer.transform = transform
                }

                //if eachView.placeholderImageView?.image == nil {
                //    eachView.makeImage()
                //}
            }

            // This fixes the glitch with a fraction of a second shadow at
            // the top of an open card from the card above it.

            if view.index <= 1 && isCompact && doesHavePrimaryTab && animated {
                let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
                shadowAnimation.fromValue = 0.5
                shadowAnimation.toValue = 0.0
                shadowAnimation.duration = animationDuration / 2
                let first = containerViews[0]
                first.layer.add(shadowAnimation, forKey: shadowAnimation.keyPath)
                first.layer.shadowOpacity = 0.0
            }

            // Animate the selected card

            let oldTransform = view.layer.transform

            view.layer.transform = CATransform3DIdentity

            let topPosition = view.frame.origin.y - contentOffsetY

            let transform = getTransform(view: view, translatedToY: -topPosition, isScale: false, isRotate: false)

            view.layer.transform = oldTransform

            view.setGestureRecognisersEnabled(false)

            // Round the bottom corners of the main tab, if it is selected and there is more tabs

            if view.index == 0 && doesHavePrimaryTab && containerViews.count > 1 {
                view.superview?.addSubview(view)

                // Handle iPhones with an eyebrow separately

                if UIDevice.current.hasAnEyebrow && animated {

                    let startPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                            lt: preferredCornerRadius,
                            rt: preferredCornerRadius,
                            lb: preferredCornerRadius,
                            rb: preferredCornerRadius)
                    let endPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                            lt: 40,
                            rt: 40,
                            lb: preferredCornerRadius,
                            rb: preferredCornerRadius)

                    animatePath(layer: view.navController.view.layer,
                            oldPath: startPath,
                            newPath: endPath,
                            duration: animationDuration)
                } else {
                    view.navController.view.layer.mask =
                            CAShapeLayer.getRoundedRectShape(
                                    frame: view.bounds,
                                    roundingCorners: [.bottomLeft, .bottomRight],
                                    withRadius: preferredCornerRadius
                            )
                }

            } else {
                view.navController.view.layer.mask = nil
            }

            if animated {
                animate(transform: transform, view: view)
                isUserInteractionEnabled = false
            } else {
                view.layer.transform = transform
            }

            DispatchQueue.main.async {
                if view.navController.view.window != nil {
                    DispatchQueue.main.async(execute: view.navController.view.layoutSubviews)
                }
            }

            // Animate cards that are above the opened one

            for i in view.index + 1..<containerViews.count {

                let eachView = self.containerViews[i]

                var transform: CATransform3D!

                if doesHavePrimaryTab && view.index == 0 && i < 4 {

                    // The 'Force' flag is only used when switching from the compact state
                    // to non-compact and vice versa. Changing fake header modes to compact,
                    // and many other things in this case are not needed, so we cut them
                    // off with a simple check

                    transform = getTransformBottomView(index: i)

                    if !force {
                        UIView.animate(withDuration: animated ? animationDuration : 0, animations: {
                            eachView.navController.titleContainer.becomeCompact()
                        })
                    }

                } else {

                    transform = self.getTransform(view: eachView, translatedToY: bounds.size.height * 1.5, isScale: true, isRotate: false)

                    eachView.setGestureRecognisersEnabled(false)
                    eachView.navController.view.layer.mask = nil
                }

                transform = transform ?? CATransform3DIdentity

                if animated && !eachView.isHidden {
                    animate(transform: transform, view: eachView)
                } else {
                    eachView.layer.transform = transform
                }

                //if eachView.placeholderImageView?.image == nil {
                //    eachView.makeImage()
                //}
            }

        } else {

            UIView.animate(withDuration: animated ? animationDuration : 0, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.7, options: [UIView.AnimationOptions.curveLinear], animations: {
                self.scrollView.zoomScale = 1
                self.savedContentOffsetY = view.frame.origin.y
                self.scrollView.contentOffset = view.frame.origin
            })

            DispatchQueue.main.async {
                DispatchQueue.main.async(execute: view.navController.view.layoutSubviews)
            }

            for view in containerViews {
                view.setGestureRecognisersEnabled(false)
            }
        }

        //if doesHavePrimaryTab || force {
        for i in firstIndex..<containerViews.count {

            let eachView = containerViews[i]

            eachView.navController.view.transform = .identity

            if eachView.isHidden {
                continue
            }

            if animated {
                let radius: CGFloat

                if UIDevice.current.hasAnEyebrow {
                    if (doesHavePrimaryTab && i == 0) {
                        radius = 0
                    } else if (i > 3 || !doesHavePrimaryTab || view.index == i) {
                        radius = 40
                    } else {
                        radius = 0
                    }
                } else {
                    radius = 0
                }

                eachView.navController.view.cornerRadius = 0

                let instance = PrimarySplitViewController.instance(for: self)!

                let roundLeftCorners = !UIDevice.current.hasAnEyebrow || instance.displayMode == .primaryHidden

                let startPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                        lt: preferredCornerRadius,
                        rt: preferredCornerRadius,
                        lb: preferredCornerRadius,
                        rb: preferredCornerRadius)
                let endPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                        lt: roundLeftCorners ? radius : 0.01,
                        rt: radius,
                        lb: roundLeftCorners ? radius : 0.01,
                        rb: radius)

                animatePath(layer: view.navController.view.layer,
                        oldPath: startPath,
                        newPath: endPath,
                        duration: animationDuration)
            } else {
                eachView.navController.view.layer.cornerRadius = 0
            }
        }

        //}

        func complete() {

            isUserInteractionEnabled = true
            locked = false

            for eachView in containerViews {

                if view.index == 0 && hasPrimaryTab && eachView.index < 4 && containerViews.count > 1 {

                    if eachView.index == 0 {
                        clearShadow(view: eachView)
                        eachView.navController.view.layer.mask = CAShapeLayer.getRoundedRectShape(frame: eachView.bounds, roundingCorners: [.bottomLeft, .bottomRight], withRadius: preferredCornerRadius)
                    }

                    continue
                }

                clearShadow(view: eachView)

                if view.index != eachView.index {
                    eachView.isHidden = true
                    eachView.viewsDisappeared()
                }

                view.navController.view.layer.mask = nil
            }

            // Remove the corner radii if they was added before.

            if UIDevice.current.hasAnEyebrow {
                for eachView in containerViews {
                    eachView.navController.view.layer.cornerRadius = 0
                }
            }

            view.focused()

            completion?()
        }

        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration, execute: complete)
        } else {
            complete()
        }

        view.navController.switchToDefault(animated: animated)

    }

    /// Restores the numbering of cards. Must be called if list of open editors was changed.
    /// Call only when `presentedView == nil`
    func restoreIndexingOrder() {
        for i in 0..<containerViews.count {
            let view = containerViews[i]
            view.index = i
        }
    }

    /// Restores card positions. Call only when `presentedView == nil`
    final func restoreCardsLocations(animated: Bool = true) {

        for i in 0..<containerViews.count {
            let view = containerViews[i]

            let savedTransform = view.layer.transform
            view.layer.transform = CATransform3DIdentity

            func updateLocation() {
                view.frame = getFrameForItem(at: view.index)
            }

            if view.isHidden || !animated {
                updateLocation()
            } else {
                UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut, animations: {
                    updateLocation()
                })
            }

            if view.isHidden {
                continue
            }

            let newTransform = getTransform(view: view, translatedToY: 0, isScale: true, isRotate: true)

            if animated {
                view.layer.transform = savedTransform
                animate(transform: newTransform, view: view)
            } else {
                view.layer.transform = newTransform
            }
        }

        updateLayoutSpecificConstants()

        if animated {
            UIView.animate(withDuration: animationDuration) {
                self.updateScrollViewContentSize()
            }
        } else {
            updateScrollViewContentSize()
        }

        if !isFullScreen && !isCompact && blocksInLine < maxBlocksInLine {

            if animated {

                // TODO: Figure out, why this does not work without a delay.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {

                    UIView.animate(withDuration: self.animationDuration, delay: 0, options: .curveEaseInOut, animations: {
                        self.scrollView.zoomScale = self.scrollView.minimumZoomScale
                        self.scrollView.contentOffset = .zero
                    })
                }

            } else {
                scrollView.zoomScale = scrollView.minimumZoomScale
                scrollView.contentOffset = .zero
            }
        }
    }

    deinit {
        for view in containerViews {
            let editor = view.navController?.editorViewController
            (editor as? FileEditor)?.editor?.closeEditor()
        }
    }
}



