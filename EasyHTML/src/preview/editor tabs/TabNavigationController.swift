import UIKit

fileprivate var iOSVersionIsBelow11 = (UIDevice.current.systemVersion as NSString).floatValue < 11.0

class TabNavigationController: ThemeColoredNavigationController, UINavigationControllerDelegate, UINavigationBarDelegate, NotificationHandler {

    var shouldHideBackButton = true

    func fixResizeIssue() {
        guard iOSVersionIsBelow11 else {
            return
        }

        isNavigationBarHidden = true
        isNavigationBarHidden = false

        view.bringSubviewToFront(titleContainer)
    }

    func goBack() {
        let switcherView = parentView.parentView!

        guard switcherView.presentedView == parentView else {
            return
        }

        if switcherView.hasPrimaryTab && parentView.index == 1 && switcherView.containerViews.count == 2 {
            switcherView.animateBottomViewOut()
        } else {
            switcherView.animateOut()
        }
    }

    var editorViewController: UIViewController! {
        didSet {
            if editorViewController != nil && shouldPresentView {
                presentView()
            }
        }
    }

    func hideView() {
        editorViewController?.removeFromParent()

        let message: EditorMessage = .custom(EDITOR_ENABLE_LOW_ENERGY_MODE)

        if let fileEditor = editorViewController as? FileEditor,
           fileEditor.canHandleMessage(message: message) {

            fileEditor.handleMessage(message: message, userInfo: nil)
        }
    }

    private var shouldPresentView: Bool = false

    func presentView() {

        guard editorViewController != nil else {
            shouldPresentView = true
            return
        }

        viewControllers = [editorViewController]

        let message: EditorMessage = .custom(EDITOR_DISABLE_LOW_ENERGY_MODE)

        if let fileEditor = editorViewController as? FileEditor,
           fileEditor.canHandleMessage(message: message) {

            fileEditor.handleMessage(message: message, userInfo: nil)
        }
    }

    weak var parentView: EditorTabView!
    var isFullScreen = false

    var titleContainer = TabTitleContainerView()

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard !isFullScreen else {
            return
        }

        if let view = topViewController?.view {
            let dy = view.frame.origin.y - 64
            view.frame.origin.y += 64 - view.frame.origin.y
            view.frame.size.height += dy
        }

        navigationBar.isHidden = true
        navigationBar.isHidden = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        view.isOpaque = true

        titleContainer = TabTitleContainerView(frame: navigationBar.bounds)

        view.addSubview(titleContainer)

        view.leftAnchor.constraint(equalTo: titleContainer.leftAnchor).isActive = true
        view.topAnchor.constraint(equalTo: titleContainer.topAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: titleContainer.rightAnchor).isActive = true
        titleContainer.heightAnchor.constraint(equalToConstant: 64).isActive = true

        switchToCompact(animated: false)

        setupThemeChangedNotificationHandling()
        updateTheme()
    }

    func updateTheme() {

        titleContainer.updateTheme()
    }

    func switchToCompact(animated: Bool = true) {
        titleContainer.isHidden = false
        isFullScreen = false

        if animated {
            UIView.animate(withDuration: 0.4, animations: {

                self.titleContainer.alpha = 1
                self.navigationBar.alpha = 0

                //self.view.layoutSubviews()
                //self.viewDidLayoutSubviews()
            }, completion: {
                _ in
                if !self.isFullScreen {
                    self.navigationBar.isHidden = true
                }
            })
        } else {
            titleContainer.alpha = 1
            navigationBar.alpha = 0
            //self.navigationBar.isHidden = true

            //self.view.layoutSubviews()
            //self.viewDidLayoutSubviews()
        }
    }

    func switchToDefault(animated: Bool = true) {
        isFullScreen = true
        navigationBar.isHidden = false

        if animated {
            UIView.animate(withDuration: animated ? 0.4 : 0, animations: {

                self.titleContainer.alpha = 0
                self.navigationBar.alpha = 1

                self.view.layoutSubviews()
            }, completion: {
                _ in
                if self.isFullScreen {
                    self.titleContainer.isHidden = true
                }
            })
        } else {
            titleContainer.alpha = 0
            navigationBar.alpha = 1
            if view.window != nil {
                view.layoutSubviews()
            }
            titleContainer.isHidden = true
        }
    }

    func updateTitle() {
        titleContainer.titleLabel.text = editorViewController?.title ?? ""
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        updateTitle()
    }

    deinit {
        clearNotificationHandling()
    }
}
