
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
    
    // Переменные, используемые при 3D-layout'e.
    
    let angle: CGFloat = 40.0
    let scaleOut: CGFloat = 0.95
	var switcherViewPadding: CGFloat = 100
    
    // Переменные, используемые при
    // 2D-layout'e.
    
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
            return false
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
        
        let animation = self.layer.animation(forKey: "bounds.size")
        
        let rotationAnimationDuration = animation?.duration ?? 0
        
        let doesHavePrimaryTab = self.hasPrimaryTab
        
        savedContentOffsetY = nil
        
        if isCompact {
        
            updateScrollViewContentSize()
            
            let contentOffsetY = self.contentOffsetY
            
            let count = containerViews.count
            
            for i in 0 ..< count {
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
                    
                    if view == self.presentedView  {
                        let translationY = view.frame.origin.y - contentOffsetY
                        
                        view.layer.transform = CATransform3DMakeTranslation(0, -translationY, CGFloat(zIndexModifier * CGFloat(view.index)))
                    } else {
                        view.layer.transform = transform
                    }
                    
                    // Наконец-то я нашел, как исправить ошибку
                    // из-за которой размер UINavigationBar не
                    // обновлялся при повороте экрана на iOS < 11
                    // Бомбит иногда с UIKit...
                    
                    view.navController.fixResizeIssue()
                    view.navController.view.layer.mask = nil // А это чтоб при смене layout traits углы закругленные убирались
                    view.navController.view.cornerRadius = 0
                }
                
                if doesHavePrimaryTab && isFullScreen && presentedView.index == 0 {
                    if i == 0 {
                        if count > 1 {
                            let primaryTabBounds = CGRect(
                                x: 0,
                                y: 0,
                                width: self.bounds.width,
                                height: getMainViewHeight() - insets.bottom
                            )
                            
                            let path = CAShapeLayer.getRoundedRectPath(frame: primaryTabBounds, roundingCorners: [.bottomLeft, .bottomRight], withRadius: self.preferredCornerRadius)
                            
                            // Просто ради удовлетворения моего внутреннего перфекционизма
                            // При повороте устройства без условного перехода на анимацию
                            // смены слоя-маски, маска с закруглением углов меняется моментально
                            // и это выглядит не очень красиво. Так что я решил заморочиться
                            // и сделать так, чтобы маска менялась анимированно. Теперь
                            // все работает идеально.
                            
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
                        
                        // У текущего окна тень не должна быть в любом случае. Зачем она?
                        
                        // setupShadow(view: view)
                        
                    } else if i < 4 {
                        
                        // Не забываем обновлять фрейм у нижних вьюшек.
                        // Поскольку у нас все супероптимизировано
                        // и фреймы не обновляются там, где не надо,
                        // надо железно делать это там, где это надо.
                        view.isHidden = false // - на всякий случай
                        view.layer.transform = CATransform3DIdentity
                        
                        view.frame = getFrameForItem(at: view.index)
                        
                        if(!view.navController.titleContainer.isCompact) {
                            view.navController.titleContainer.becomeCompact()
                            view.setGestureRecognisersEnabled(true)
                        }
                        
                        // Аналогично случаю с главной вкладкой.
                        // Закругление углов есть и на нижних вьюшках,
                        // их тоже надо обновлять анимированно.
                        
                        let path = CAShapeLayer.getRoundedRectPath(frame: bounds, roundingCorners: [.topLeft, .topRight], withRadius: self.preferredCornerRadius)
                        
                        if rotationAnimationDuration != 0 && view.navController.view.layer.mask != nil {
                            
                            let startPath = (view.navController.view.layer.mask as! CAShapeLayer).path!
                            
                            animatePath(layer: view.navController.view.layer, oldPath: startPath, newPath: path, duration: rotationAnimationDuration)
                        } else {
                            let maskLayer = CAShapeLayer()
                            maskLayer.path = path
                            view.navController.view.layer.mask = maskLayer
                        }
                        
                        view.layer.transform = getTransformBottomView(index: i)
                        
                        // Обновляем размеры тени. Можно было бы вообще не трогать тени,
                        // просто один раз их включить и забыть, но внутренний голос говорит
                        // мне "Эй! Ты раньше в C память экономил выбирая менее ёмкие типы
                        // данных, а в 3Д-движке на яве вообще поднял производительность
                        // на 20% одной лишь оптимизацией циклов. Куда пропала твоя тяга к
                        // оптимизации всего и вся? А ну быстро тени оптимизировал!"
                        // Да. Тени жрут процессорное время
                        
                        setupShadow(view: view)
                    } else {
                        view.navController.view.layer.mask = nil
                    }
                } else {
                    view.navController.view.layer.mask = nil
                }
                
                if !isFullScreen {
                    for i in 0 ..< count {
                        let view = containerViews[i]
                        
                        setupShadow(view: view)
                    }
                }
            }
            
            scrollView.minimumZoomScale = 1
            scrollView.zoomScale = 1
        } else {
            
            // Ниже то, что касается 2D-переключателя вкладок.
            
            for i in 0 ..< containerViews.count {
                let view = containerViews[i]
                
                view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                
                view.layer.transform = CATransform3DIdentity
                
                if !isFullScreen || view.index == presentedView.index {
                    view.frame = getFrameForItem(at: i) // Опять же, обновляем фрейм только у текущего окна.
                                                        // Либо у всех, если мы не в полноэкранном режиме.
                }
                
                // Вспомнил времена, когда делал 2Д-движок для BPOS.
                // В войне за каждый FPS делал такие нереальные способы
                // оптимизации, что сейчас поражаюсь...
                
                if !isFullScreen {
                    
                    // Тень ставим только если мы не в полноэкранном режиме.
                    
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
        
        backgroundColor = .darkGray
        
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
		return degrees * CGFloat.pi / 180.0
	}
    
    final func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return zoomContainer
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
    
    /// Флаг, обозначающий, заблокировано ли взаимодействие с свитчером. (например, во время анимации)
    
    internal var locked: Bool = false
    
    /// Оптимизированная синхронная функция, добавляющая вкладки в свитчер, не анимируя ничего.
    
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
        
        scrollViewDidScroll(scrollView) // Оно обновит: что надо спрятать, а что нет.
        
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
            
            // Я тебя знаю, ты можешь подумать что-то в роде
            // "Хмм, стоит флаг force, значит, он должен обходить блокировки"
            // "Блокировка ставится строчкой выше в if'e, так почему бы мне"
            // "не переставить эти строки местами и убрать этот небезопасный флажок?"
            // НЕ ДЕЛАЙ ЭТОГО!
            // флажок force помимо обхода блокировок отключает воздействие функции на
            // поле locked, а отключение флага может привести к тому, что при постоянном тыкании
            // на файл в списке получится эффект гонки и навигейшн-контроллеры
            // не будут переводиться в компактный режим.
            // Короче, просто не делай этого. Я слишком долго искал этот баг и будет глупо
            // допустить его снова.
            
            animateOut(animated: animated, force: true, completion: {
                self.addContainerView(view, animated: animated, force: true, completion: completion)
            })
            return
        }
        
        var animated = animated
        
        if !self.isCompact && animated && self.blocksInLine < self.maxBlocksInLine && !containerViews.isEmpty {
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
        
        let maxContentOffsetY = self.maxContentOffsetY
        let oldContentOffsetY = scrollView.contentOffset.y
        
        view.frame = getFrameForItem(at: view.index)
        
        // Даем функции getTransform понять, что мы сейчас "находимся"
        // в нижнем положении скролла, поскольку от этого зависит
        // параллакс - поворот карточки по оси X
        
        // Кстати, это не нужно, если мы находимся в 2D-режиме.
        
        if isCompact {
            scrollView.contentOffset.y = maxContentOffsetY
        }
        
        let newTransform = getTransform(
            view: view,
            translatedToY: 0,
            isScale: true,
            isRotate: true
        )
        
        // Возвращаем положение скролла обратно
        
        if isCompact {
            scrollView.contentOffset.y = oldContentOffsetY
        }
        
        // Скроллим до самого низа
        
        scrollView.setContentOffset(CGPoint(x: 0, y: maxContentOffsetY), animated: animated)
        
        if isCompact {
            if animated {
                
                // Анимация "вылета" карточки снизу
                
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
                
                // Анимация появления карточки с скалингом.
                
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
        
        // ВНИМАНИЕ! МАГИЯ!
        // Не трогать!
        
        // Послание мне в будущее
        // Чел. Магия вне хогвартса запрещена.
        // Как итог - с версии 1.4 до версии 1.4.2 приложение работало ДИКО
        // криво на устройствах с iOS 10. Подумай об этом в следующий раз,
        // когда решишь использовать магию, которую сам не понимаешь. Ок?
        
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
        if(presentedView == nil) {
            restoreCardsLocations(animated: animated)
        } else if animated {
            if(containerViews.count >= 4) {
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
                    self.animatePath(layer: presentedView.navController.view.layer, oldPath: oldPath, newPath: newPath, duration: animationDuration, timingFunction: .easeOut)
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
        
        // В рамках библиотеки смены вкладок, animated
        // ставится в true, только если вкладка была
        // выкинута пользователем. Если она была закрыта
        // в ходе сваппинга контроллеров из свитчера в
        // свитчер, то animated ставится в false.
        // Хоть и по названию переменной это неочевидно,
        // здесь мы будем использовать этот флаг, чтобы
        // понять, что надо создавать NoEditorController.
        
        
        if containerViews.isEmpty {
            
            // Тут есть забавная бага: При перевороте экрана на айфонах с большой диагональю экрана свап работает
            // так, что при перевороте экрана создается пустой редактор, хотя он здесь не нужен. Поэтому
            // весь блок создания засунут в animated, ведь эта переменная false только когда мы свапаем
            // контроллеры. Сваппер сам создась пустой редактор если надо будет
            
            if animated {
                
                let emptyEditor = NoEditorPreviewController.present(animated: isCompact, on: self)
            
                // Немного странно работает анимация создания пустого редактора
                // в 2D-лайоуте. Поэтому костылим другую.
                
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
                let rotation = -radians(degrees: angle + blockTop / self.bounds.height * 40)
                transform = CATransform3DRotate(transform, rotation, 1.0, 0.0, 0.0)
            }
            
            if isScale {
                
                if UIDevice.current.hasAnEyebrow && UIApplication.shared.statusBarOrientation.isLandscape {
                    
                    var scale = scaleOut
                    
                    // высота брови у iPhone X - 30 пикселей
                    
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
        
        if !isFullScreen { return }
        isFullScreen = false
        
        var presentedView = self.presentedView!
        
        presentedView.blured()
        
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
            view.isHidden = viewbottom < 0 || viewtop > self.frame.height
            
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
            
            /*
             Не убирать!
             Это убирает глюк с появляющейся на долю секунды
             тень вверху открытой карточки от вышестоящей.
             */
            
            if view.index == 0 && presentedView.index == 1 && isCompact && hasPrimaryTab && animated {
                
                view.layer.shadowOpacity = 0.0
                
                let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
                shadowAnimation.fromValue = 0.0
                shadowAnimation.toValue = 0.5
                shadowAnimation.duration = animationDuration / 2
                // Делаем делэй на половину длины анимации
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
            
            for i in firstIndex ..< self.containerViews.count {
                let view = self.containerViews[i]
                
                let oldTransform = view.layer.transform
                view.layer.transform = CATransform3DIdentity
                
                setupView(view: view)
                
                if !hasPrimaryTab || presentedView.index != 0 || i >= 4 {
                    if i > presentedView.index {
                        view.layer.transform = self.getTransform(view: view, translatedToY: self.bounds.size.height, isScale: true, isRotate: false)
                    } else if i < presentedView.index {
                        view.layer.transform = self.getTransform(view: view, translatedToY: -self.bounds.size.height, isScale: false, isRotate: false)
                    } else {
                        view.layer.transform = oldTransform
                    }
                } else {
                    view.layer.transform = oldTransform
                }
                
                let transform = self.getTransform(view: view, translatedToY: 0.0, isScale: true, isRotate: true)
                
                if i == 0 && UIDevice.current.hasAnEyebrow && hasPrimaryTab {
                    
                    if animated {
                        let path1 = CAShapeLayer.getRoundedRectPath(size: view.bounds.size, lt: 40, rt: 40, lb: self.preferredCornerRadius, rb: self.preferredCornerRadius)
                        let path2 = CAShapeLayer.getRoundedRectPath(size: view.bounds.size, lt: self.preferredCornerRadius, rt: self.preferredCornerRadius, lb: self.preferredCornerRadius, rb: self.preferredCornerRadius)
                        
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
            for i in firstIndex ..< self.containerViews.count {
                let view = containerViews[i]
                
                setupView(view: view)
            }
            UIView.animate(withDuration: animated ? animationDuration : 0, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.9, options: [UIView.AnimationOptions.curveLinear], animations: {
                self.scrollView.setZoomScale(self.scrollView.minimumZoomScale, animated: animated)
            })
        }
        
        isUserInteractionEnabled = false
        
        for i in firstIndex ..< self.containerViews.count {
            let view = self.containerViews[i]
            
            if animated && presentedView.index == i {
                if !hasPrimaryTab || !isCompact || i > 3 || presentedView.index != 0 {
                    
                    let instance = PrimarySplitViewController.instance(for: self)!
                    
                    if UIDevice.current.hasAnEyebrow {
                        var roundLeftCorners = !UIDevice.current.hasAnEyebrow || instance.displayMode == .primaryHidden

                        let endPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                                                                      lt: self.preferredCornerRadius,
                                                                      rt: self.preferredCornerRadius,
                                                                      lb: self.preferredCornerRadius,
                                                                      rb: self.preferredCornerRadius)
                        let startPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                                                                        lt: roundLeftCorners ? 40 : 0.01,
                                                                        rt: 40,
                                                                        lb: roundLeftCorners ? 40 : 0.01,
                                                                        rb: 40)

                        animatePath(layer: view.navController.view.layer,
                                    oldPath: startPath,
                                    newPath: endPath,
                                    duration: animationDuration)
                        
                        view.navController.view.cornerRadius = self.preferredCornerRadius
                    } else {
                        animateCornerRadius(layer: view.navController.view.layer, from: 0.01, to: self.preferredCornerRadius)
                    }
                
                    
                    continue
                }
            }
            
            view.navController.view.layer.cornerRadius = self.preferredCornerRadius
        }
        
        func complete() {
            
            for view in containerViews {
                view.navController.view.layer.mask = nil
            }
            
            self.isUserInteractionEnabled = true
            self.scrollViewDidScroll(self.scrollView)
            
            if !force {
                self.locked = false
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
        guard isFullScreen else { return }
        
        let prevView = presentedView!
        let newView = containerViews[index]
        
        prevView.isHidden = true
        prevView.blured()
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
            
            view.isHidden = maxY < 0 || minY > self.frame.height
            
            if oldIsHidden != view.isHidden {
                if view.isHidden {
                    view.viewsDisappeared()
                } else {
                    view.viewsAppeared()
                }
            }
            
            if view.isHidden { continue }
            
            view.layer.transform = self.getTransform(view: view, translatedToY: 0, isScale: true, isRotate: true)
            
        }
    }
    
    var isCompact: Bool {
        get {
            return maxBlocksInLine <= 1
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
        
        if UIDevice.current.hasAnEyebrow {
            return UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        }
        return .zero
    }
    
    private func getTransformBottomView(index: Int) -> CATransform3D {
        
        let countOfAlwaysVisibleCards = min(self.containerViews.count - 1, 3)
        
        let view = containerViews[index]
        
        let oldTransform = view.layer.transform
        
        view.layer.transform = CATransform3DIdentity
        
        let top = view.frame.origin.y - contentOffsetY - bounds.height + 32 + insets.bottom
        
        var transform = self.getTransform(view: view, translatedToY: -top, isScale: false, isRotate: false)
        
        let deltaScale: CGFloat = 0.02
        
        let scale = 1 + CGFloat(index - countOfAlwaysVisibleCards) * deltaScale
        
        transform = CATransform3DScale(transform, scale, scale, 1)
        transform = CATransform3DTranslate(transform, 0, CGFloat(index - countOfAlwaysVisibleCards) * 5, 0)
        
        view.layer.transform = oldTransform
        
        view.navController.view.layer.mask =
            CAShapeLayer.getRoundedRectShape(
                frame: view.bounds,
                roundingCorners: [.topLeft, .topRight],
                withRadius: self.preferredCornerRadius
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
    
    private func animateCornerRadius(layer: CALayer, from: CGFloat, to: CGFloat)
    {
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = animationDuration
        layer.add(animation, forKey: "cornerRadius")
        layer.cornerRadius = to
    }
    
    private func getMainViewHeight() -> CGFloat {
        guard isCompact && hasPrimaryTab else {
            // Что-то идёт не так
            fatalError()
        }
        
        if(containerViews.count == 1) {
            return bounds.height
        } else if(containerViews.count < 4) {
            return bounds.height - 25 - CGFloat(containerViews.count * 5)
        } else {
            return bounds.height - 45
        }
    }
    
    func animateBottomViewOut() {
        // Миллион проверок. Потому что надо.
        
        guard !locked else { return }
        guard isFullScreen else { return }
        guard hasPrimaryTab else { return }
        guard containerViews.count == 2 else { return }
        guard presentedView.index == 1 else { return }
        
        // Блокируем свичер для юзера.
        
        locked = true
        
        let bottomView = presentedView!
        
        bottomView.setInteractionEnabled(false)
        bottomView.blured()
        
        let mainView = containerViews[0]
        
        mainView.isHidden = false
        mainView.viewsAppeared()
        mainView.navController.switchToDefault(animated: false)
        
        bottomView.navController.switchToCompact(animated: true)
        mainView.navController.titleContainer.becomeRegular()
        
        // Пляски с бубном вокруг трансформаций
        
        mainView.layer.transform = CATransform3DIdentity
        
        // Обновляем размер главного окна, Здесь самое место это сделать.
        
        mainView.frame = getFrameForItem(at: 0)
        
        // Анимировать закругление краёв
        
        if UIDevice.current.hasAnEyebrow {
            let path1 = CAShapeLayer.getRoundedRectPath(size: mainView.bounds.size, lt: self.preferredCornerRadius, rt: self.preferredCornerRadius, lb: self.preferredCornerRadius, rb: self.preferredCornerRadius)
            let path2 = CAShapeLayer.getRoundedRectPath(size: mainView.bounds.size, lt: 40, rt: 40, lb: self.preferredCornerRadius, rb: self.preferredCornerRadius)
            
            animatePath(layer: mainView.navController.view.layer, oldPath: path1, newPath: path2, duration: animationDuration)
        } else {
            // Иначе, просто анимировать закругление краёв. Благо, для этого
            // есть отдельная функция.
            
            animateCornerRadius(layer: mainView.navController.view.layer, from: self.preferredCornerRadius, to: 0)
        }
        
        let topPosition = mainView.frame.origin.y - contentOffsetY
        let mainViewTransform = self.getTransform(view: mainView, translatedToY: -topPosition, isScale: false, isRotate: false)
        
        var startTransform = CATransform3DScale(mainViewTransform, 0.8, 0.8, 1)
        startTransform = CATransform3DTranslate(startTransform, 0, bounds.height * 0.1, 0)
        
        mainView.layer.transform = startTransform
        
        animate(transform: mainViewTransform, view: mainView, timingFunction: .easeInEaseOut)
        
        // Анимируем закругление краёв. Тут немного посложнее,
        // поскольку закруглены не все края. Но зато это оптимизирует
        // рендеринг.
        
        // Форма имеет закругление 0.01, а не 0, поскольку в
        // UIKit есть баг, из-за которого анимирование закругления
        // криво работает если менять его с нуля на ненулевое значение.
        // Хотя Apple считает это "правильным поведением".
        
        let roundedCorners: UIRectCorner = [.topLeft, .topRight]
        let frame = presentedView.bounds
        
        let startPath = CAShapeLayer.getRoundedRectPath(frame: frame, roundingCorners: roundedCorners, withRadius: UIDevice.current.hasAnEyebrow ? 40 : 0.01)
        let endPath = CAShapeLayer.getRoundedRectPath(frame: frame, roundingCorners: roundedCorners, withRadius: self.preferredCornerRadius)
        
        animatePath(layer: presentedView.navController.view.layer, oldPath: startPath, newPath: endPath, duration: animationDuration)
        
        presentedView = mainView
        
        
        // Анимируем сдвиг нижней карточки вниз
        
        let bottomViewTransform = CATransform3DTranslate(bottomView.layer.transform, 0, bounds.height - 32 - insets.bottom, 0)
        animate(transform: bottomViewTransform, view: bottomView, timingFunction: .easeInEaseOut)
        
        // Ну и поскольку у CABasicAnimation нет completion-метода,
        // костылями через DispatchQueue организуем все завершающие
        // моменты. Разблокируем свичер для взаимодействия с юзером,
        // отключаем тени, и очищаем маску у показанной карточки, ибо
        // мы уже санимировали все закругления краёв до нуля.
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.locked = false
            self.clearShadow(view: mainView)
            if UIDevice.current.hasAnEyebrow {
                mainView.navController.view.layer.mask = CAShapeLayer.getRoundedRectShape(frame: mainView.bounds, roundingCorners: [.bottomLeft, .bottomRight], withRadius: self.preferredCornerRadius)
            }
            
            bottomView.viewsDisappeared()
        }
        
        // Через DispatchQueue.main.async (в следующем цикле)
        // мы обновляем navigationcontroller, чтобы он
        // понял, что находится вверху экрана и залез под статусбар.
        // Это надо делать именно асинхронно. Видать, какие-то свои
        // переменные он там обновляет только в конце цикла...
        
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
        
        // Только что сообразил что можно не использовать лямбда-выражение
        // где требуется один вызов void-функции без аргументов
        
        bottomView.navController.titleContainer.becomeCompact()
        
        bottomView.setGestureRecognisersEnabled(true)
        
        // Наконец-то я нашел, как исправить ошибку
        // из-за которой размер UINavigationBar не
        // обновлялся при повороте экрана на iOS < 11
        // Бомбит иногда с UIKit...
        
        mainView.navController.fixResizeIssue()
    }
    
    /**
        Производит анимацию "входа" в *единственную* вкладку, расположенную снизу на экране.
     */
    
    func animateBottomViewIn() {
        
        // Миллион проверок. Потому что надо.
        
        guard !locked else { return }
        guard isFullScreen else { return }
        guard hasPrimaryTab else { return }
        guard containerViews.count == 2 else { return }
        guard presentedView.index == 0 else { return }
            
        // Блокируем свичер для юзера.
        
        locked = true
        
        presentedView.setInteractionEnabled(false)
        
        let bottomView = containerViews[1]

        bottomView.navController.switchToDefault()

        bottomView.setInteractionEnabled(true)
        bottomView.setGestureRecognisersEnabled(false)
        bottomView.viewsAppeared()
        bottomView.isHidden = false // На случай если вкладка
                                    // только что добавлена функцией
                                    // addContainerViewsSilently
        
        // Анимируем открытую в данный момент карточку
        
        var transform = CATransform3DScale(presentedView.layer.transform, 0.8, 0.8, 1)
        
        // Компенсировать факт того, что якорная точка трансформации
        // находится сверху, сдвигом вниз на половину обратного масштаба
        // увеличения
        
        transform = CATransform3DTranslate(transform, 0, presentedView.bounds.height * 0.1, 0)
        
        // Если это iPhone X - то заморачиваемся с закруглением краёв
        if UIDevice.current.hasAnEyebrow {
            let path1 = CAShapeLayer.getRoundedRectPath(size: presentedView.bounds.size, lt: 40, rt: 40, lb: self.preferredCornerRadius, rb: self.preferredCornerRadius)
            let path2 = CAShapeLayer.getRoundedRectPath(size: presentedView.bounds.size, lt: self.preferredCornerRadius, rt: self.preferredCornerRadius, lb: self.preferredCornerRadius, rb: self.preferredCornerRadius)
            
            animatePath(layer: presentedView.navController.view.layer, oldPath: path1, newPath: path2, duration: animationDuration)
        } else {
            // Иначе, просто анимировать закругление краёв. Благо, для этого
            // есть отдельная функция.
            
            animateCornerRadius(layer: presentedView.navController.view.layer, from: 0, to: self.preferredCornerRadius)
        }
       
        
        // Анимировать трансформацию.
        
        animate(transform: transform, view: presentedView, timingFunction: .easeInEaseOut)
        
        // Перенести назад показанную в данный момент карточку.
        // Поскольку на ней не должно быть тени от нижних карточек
        // она автоматически переносится на передний план, когда показана.
        
        zoomContainer.bringSubviewToFront(bottomView)
        
        // Анимируем сдвиг нижней карточки вверх
        
        // Пляски с бубном вокруг трансформаций
        
        let oldTransform = bottomView.layer.transform
        bottomView.layer.transform = CATransform3DIdentity
        
        let topPosition = bottomView.frame.origin.y - contentOffsetY
        let bottomViewTransform = self.getTransform(view: bottomView, translatedToY: -topPosition, isScale: false, isRotate: false)
        bottomView.layer.transform = oldTransform
        
        // Такая нехитрая проверка на инициализированность
        // контроллера.
        
        let startShapeLayer = bottomView.navController.view.layer.mask as? CAShapeLayer
        
        // animateBottomViewIn может быть вызван,
        // когда контроллен непроинициализирован,
        // и не имеет стартовой маски. В этом
        // случае мы не анимируем закругление.
        
        if let startPath = startShapeLayer?.path {
        
            // Анимируем закругление краёв. Тут немного посложнее,
            // поскольку закруглены не все края. Но зато это оптимизирует
            // рендеринг.
            
            // Конечная форма имеет закругление 0.01, а не 0, поскольку в
            // UIKit есть баг, из-за которого анимирование закругления
            // криво работает если менять его с нуля на ненулевое значение.
            // Хотя Apple считает это "правильным поведением".
            
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
        
        // Анимирование трансформации
        
        animate(transform: bottomViewTransform, view: bottomView, timingFunction: .easeInEaseOut)
        
        // Ну и поскольку у CABasicAnimation нет completion-метода,
        // костылями через DispatchQueue организуем все завершающие
        // моменты. Разблокируем свичер для взаимодействия с юзером,
        // отключаем тени, и очищаем маску у показанной карточки, ибо
        // мы уже санимировали все закругления краёв до нуля.
        
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
        
        // обновляем navigationcontroller, чтобы он
        // понял, что находится вверху экрана и залез под статусбар.
        // Это надо делать именно через setNeedsLayout. Видать, какие-то свои
        // переменные он там обновляет только в конце цикла...
        
        bottomView.navController.view.setNeedsLayout()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let nb = bottomView.navController.navigationBar
            nb.layoutSubviews()
        }
        
        mainView.setInteractionEnabled(true)
        mainView.setGestureRecognisersEnabled(false)
        
    }
    
    /**
        Производит анимацию "входа" в определенную вкладку. Вызывать только, если `presentedView == nil`
     */
    
    func animateIn(animated: Bool = true, force: Bool = false, view: EditorTabView, completion: (() -> ())? = nil) {
        
        if locked && !force {
            return
        }
        
        if isFullScreen && !force { return }
        isFullScreen = true
        
        if animated && !force {
            self.locked = true
        }
        
        let contentOffsetY = self.contentOffsetY
        
        savedContentOffsetY = self.contentOffsetY
        
        presentedView = view
        
        //view.hideImage()
        
        scrollView.isScrollEnabled = false
        scrollView.contentOffset.y = contentOffsetY

        let doesHavePrimaryTab = self.hasPrimaryTab
        
        let firstIndex = getFirstVisibleIndex()
        view.setInteractionEnabled(true)
        
        if isCompact {
            
            // Анимируем карточки, находящиеся ниже по индексу
            // чем нажатая.
            
            for i in firstIndex ..< view.index {
                let eachView = self.containerViews[i]
                
                eachView.setGestureRecognisersEnabled(false)
                eachView.navController.view.layer.mask = nil
                
                if eachView.isHidden { continue }
                
                let transform = self.getTransform(view: eachView, translatedToY: -self.bounds.size.height, isScale: true, isRotate: false)
                
                if animated {
                    animate(transform: transform, view: eachView)
                } else {
                    eachView.layer.transform = transform
                }
                
                //if eachView.placeholderImageView?.image == nil {
                //    eachView.makeImage()
                //}
            }
            
            /*
             Не убирать!
             Это убирает глюк с появляющейся на долю секунды
             тень вверху открытой карточки от вышестоящей.
             */
            
            if view.index <= 1 && isCompact && doesHavePrimaryTab && animated {
                let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
                shadowAnimation.fromValue = 0.5
                shadowAnimation.toValue = 0.0
                shadowAnimation.duration = animationDuration / 2
                let first = containerViews[0]
                first.layer.add(shadowAnimation, forKey: shadowAnimation.keyPath)
                first.layer.shadowOpacity = 0.0
            }
            
            // Анимируем нажатую карточку
            
            let oldTransform = view.layer.transform
            
            view.layer.transform = CATransform3DIdentity
            
            let topPosition = view.frame.origin.y - contentOffsetY
            
            let transform = self.getTransform(view: view, translatedToY: -topPosition, isScale: false, isRotate: false)
            
            view.layer.transform = oldTransform
            
            view.setGestureRecognisersEnabled(false)
            
            // Если у нас есть главная неединственная вкладка
            // и она нажата в данный момент,
            // то закругляем нижние углы
            
            if view.index == 0 && doesHavePrimaryTab && containerViews.count > 1 {
                view.superview?.addSubview(view)
                
                // Если имеем дело с десятым айфоном, то закругляем верхние на 40 пикселей.
                // Дабы красиво было.
                
                if UIDevice.current.hasAnEyebrow && animated {
                    
                    let startpath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                                                                    lt: self.preferredCornerRadius,
                                                                    rt: self.preferredCornerRadius,
                                                                    lb: self.preferredCornerRadius,
                                                                    rb: self.preferredCornerRadius)
                    let endPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                                                                  lt: 40,
                                                                  rt: 40,
                                                                  lb: self.preferredCornerRadius,
                                                                  rb: self.preferredCornerRadius)
                    
                    animatePath(layer: view.navController.view.layer,
                                oldPath: startpath,
                                newPath: endPath,
                                duration: animationDuration)
                } else {
                    view.navController.view.layer.mask =
                        CAShapeLayer.getRoundedRectShape(
                            frame: view.bounds,
                            roundingCorners: [.bottomLeft, .bottomRight],
                            withRadius: self.preferredCornerRadius
                    )
                }
                
            } else {
                view.navController.view.layer.mask = nil
            }

            if animated {
                self.animate(transform: transform, view: view)
                self.isUserInteractionEnabled = false
            } else {
                view.layer.transform = transform
            }
            
            DispatchQueue.main.async {
                if view.navController.view.window != nil {
                    DispatchQueue.main.async(execute: view.navController.view.layoutSubviews)
                }
            }
            
            // Анимируем карточки, находящиеся выше по индексу
            // чем нажатая
            
            for i in view.index + 1 ..< self.containerViews.count {
                
                let eachView = self.containerViews[i]
                
                var transform: CATransform3D!
                
                if doesHavePrimaryTab && view.index == 0 && i < 4 {
                    
                    // Костыль, конечно, но почему бы и нет.
                    // Флажок Force используется только при свитче из компактного состояния
                    // в некомпактное и наоборот. Смена режимов фейк-заголовков
                    // на компактный, и много других вещей в этом случае не
                    // нужны, так что отсекаем их простой проверкой
                    
                    transform = getTransformBottomView(index: i)
                    
                    if !force {
                        UIView.animate(withDuration: animated ? animationDuration : 0, animations: {
                            eachView.navController.titleContainer.becomeCompact()
                        })
                    }
                    
                } else {
                    
                    transform = self.getTransform(view: eachView, translatedToY: self.bounds.size.height * 1.5, isScale: true, isRotate: false)
                    
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
        
        // Не спрашивай зачем в условии стоит флаг force. Так надо.
        // А если серьезно - то при развороте iPhone 6+
        // меняет layout traits. И чтобы при этом правильно
        // отработал свич контроллеров редактора из одного
        // свичера в другой, в частности надо раздавать углы закругления там, где
        // это нужно.
        
        //if doesHavePrimaryTab || force {
            for i in firstIndex ..< self.containerViews.count {
                
                let eachView = self.containerViews[i]
            
                eachView.navController.view.transform = .identity
            
                if eachView.isHidden { continue }
                
                if animated {
                    let radius: CGFloat
                    
                    if UIDevice.current.hasAnEyebrow {
                        if(doesHavePrimaryTab && i == 0) {
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
                    
                    var roundLeftCorners = !UIDevice.current.hasAnEyebrow || instance.displayMode == .primaryHidden
                    
                    let startpath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                                                                    lt: self.preferredCornerRadius,
                                                                    rt: self.preferredCornerRadius,
                                                                    lb: self.preferredCornerRadius,
                                                                    rb: self.preferredCornerRadius)
                    let endPath = CAShapeLayer.getRoundedRectPath(size: view.bounds.size,
                                                                  lt: roundLeftCorners ? radius : 0.01,
                                                                  rt: radius,
                                                                  lb: roundLeftCorners ? radius : 0.01,
                                                                  rb: radius)
                    
                    animatePath(layer: view.navController.view.layer,
                                oldPath: startpath,
                                newPath: endPath,
                                duration: animationDuration)
                } else {
                    eachView.navController.view.layer.cornerRadius = 0
                }
            }
        //}
        
        func complete() {

            self.isUserInteractionEnabled = true
            self.locked = false
            
            for eachview in self.containerViews {
                
                if view.index == 0 && self.hasPrimaryTab && eachview.index < 4 && containerViews.count > 1 {
                    
                    if eachview.index == 0 {
                        self.clearShadow(view: eachview)
                        eachview.navController.view.layer.mask = CAShapeLayer.getRoundedRectShape(frame: eachview.bounds, roundingCorners: [.bottomLeft, .bottomRight], withRadius: preferredCornerRadius)
                    }
                    
                    continue
                }
                
                self.clearShadow(view: eachview)
                
                if view.index != eachview.index {
                    eachview.isHidden = true
                    eachview.viewsDisappeared()
                }
                
                view.navController.view.layer.mask = nil
            }
            
            // Поскольку ради красивой анимации на iPhone X
            // мы анимируем закругление до 40 пикселей (чтобы
            // гармонично вписывалось в экран), логично потом очистить
            // закругление, дабы упростить рендер
            
            if UIDevice.current.hasAnEyebrow {
                for eachView in self.containerViews {
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
    
    /**
        Восстанавливает нумерацию карточек. Необходимо вызывать после каждого изменения списка открытых редакторов.
     */
    
    func restoreIndexingOrder() {
        for i in 0 ..< containerViews.count {
            let view = containerViews[i]
            view.index = i
        }
    }
    
    /**
        Восстанавливает позиционирование карточек. Использовать только, если `presentedView == nil`
     */
    
    final func restoreCardsLocations(animated: Bool = true) {
        
        for i in 0 ..< containerViews.count {
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
        
        self.updateLayoutSpecificConstants()
        
        if animated {
            UIView.animate(withDuration: animationDuration) {
                self.updateScrollViewContentSize()
            }
        } else {
            self.updateScrollViewContentSize()
        }
        
        if !self.isFullScreen && !isCompact && blocksInLine < maxBlocksInLine {
            
            if animated {
                
                // Без небольшой задержки работает криво. Хз почему. #TODO
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    
                    UIView.animate(withDuration: self.animationDuration, delay: 0, options: .curveEaseInOut, animations: {
                        self.scrollView.zoomScale = self.scrollView.minimumZoomScale
                        self.scrollView.contentOffset = .zero
                    })
                }
                
            } else {
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
                self.scrollView.contentOffset = .zero
            }
        }
    }
    
    deinit {
        for view in containerViews {
            let editor = view.navController?.editorViewController
            
            (editor as? FileEditor)?.editor?.closeEditor() // Пока :с
        }
    }
}



