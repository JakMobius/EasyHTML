import UIKit

class PreferencesMenuNavigationController: ThemeColoredNavigationController {

    var clazz: PreferencesMenu.Type?;

    override func viewDidLoad() {
        if (clazz == nil) {
            return
        }
        let vc = clazz!.init()
        viewControllers = [vc]
    }
}

class PreferencesMenu: AlternatingColorTableView {

    internal static func present(from: UIViewController, clazz: PreferencesMenu.Type) {
        let vc = PreferencesMenuNavigationController()
        vc.clazz = clazz
        vc.modalPresentationStyle = .formSheet

        from.present(vc, animated: true, completion: nil)
    }

    internal var nc: PreferencesMenuNavigationController?

    @objc func exit(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    override func updateTheme() {

        tableView.backgroundColor = userPreferences.currentTheme.background
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView = UITableView(frame: tableView.frame, style: .grouped)

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: localize("ready"), style: .done, target: self, action: #selector(exit(_:)))
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        userPreferences.currentTheme.statusBarStyle
    }
}
