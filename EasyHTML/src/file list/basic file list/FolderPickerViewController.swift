//
//  FolderPickerViewController.swift
//  EasyHTML
//
//  Created by Артем on 15.04.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class FolderPickerViewController: BasicMasterController, UINavigationControllerDelegate {

    private(set) var fileListManager: FileListManager! = nil

    static var sceneUserInfoKey: String = "F"

    static func instance(for view: UIView) -> FolderPickerViewController! {
        if #available(iOS 13.0, *) {
            var window: UIWindow?

            if let view = view as? UIWindow {
                window = view
            } else {
                window = view.window
            }

            guard let session = window?.windowScene?.session else {
                return nil
            }

            var controller = session.userInfo![sceneUserInfoKey] as? FolderPickerViewController
            if controller == nil {
                controller = FolderPickerViewController()
                session.userInfo![sceneUserInfoKey] = controller
            }

            return controller
        } else {
            if _instance == nil {
                _instance = FolderPickerViewController()
            }
            return _instance
        }
    }

    private static var _instance: FolderPickerViewController!

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        fileListManager?.filesRelocationManager?.controllerChanged()
    }

    internal class Cell: UITableViewCell {
        internal override func layoutSubviews() {
            super.layoutSubviews()
            if (imageView!.image != nil) {
                imageView?.frame = CGRect(x: 16, y: frame.height / 2 - 16, width: 32, height: 32)
                textLabel!.frame.size.width = contentView.frame.width - 70
                textLabel!.frame.origin.x = 64
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupToolBar()

        title = localize("folders")

        tableView = UITableView(frame: tableView.frame, style: .grouped)

        updateStyle()

        navigationItem.backBarButtonItem = UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil)

        tableView.register(Cell.self, forCellReuseIdentifier: "cell")

        clearsSelectionOnViewWillAppear = false

        setupThemeChangedNotificationHandling()

        edgesForExtendedLayout = []
    }

    internal func setup(parent: UINavigationController) {
        fileListManager = FileListManager(parent: parent)

        parent.delegate = self

        let masterViewController = LocalFileListTableView()
        masterViewController.fileListManager = fileListManager
        parent.viewControllers.append(masterViewController)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {

        50
    }

    override func updateTheme() {

        super.updateTheme()
        updateStyle()
        updateToolBar()
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = super.tableView(tableView, viewForHeaderInSection: section)

        view?.backgroundColor = userPreferences.currentTheme.background

        return view
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        50
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0) {

            if UIDevice.current.userInterfaceIdiom == .pad {
                return localize("onthispad")
            }
            return localize("onthisphone")
        } else {
            return localize("cloudservices")
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        cell.textLabel!.font = UIFont.systemFont(ofSize: 14)

        if (indexPath.section == 0) {
            cell.textLabel!.text = localize("documents")
        } else if (indexPath.row == 0) {
            cell.textLabel!.text = "Dropbox"
            cell.imageView!.image = #imageLiteral(resourceName: "dropbox")
        } else if (indexPath.row == 1) {
            cell.textLabel!.text = "FTP / SFTP"

            if userPreferences.currentTheme.isDark {
                cell.imageView!.image = #imageLiteral(resourceName: "network").invertedImage()
            } else {
                cell.imageView!.image = #imageLiteral(resourceName: "network")
            }


        } else if (indexPath.row == 2) {
            cell.textLabel!.text = "GitHub"

            if userPreferences.currentTheme.isDark {
                cell.imageView!.image = UIImage(named: "githublogo-light")
            } else {
                cell.imageView!.image = UIImage(named: "githublogo-dark")
            }
        } else {
            cell.imageView!.image = nil
        }

        cell.textLabel?.textColor = userPreferences.currentTheme.cellTextColor

        cell.accessoryType = .disclosureIndicator

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath.section == 0) {

            if let controller = fileListManager.getCachedController(for: URL(string: FileBrowser.filesFullPath)!, with: .local) {
                navigationController!.pushViewController(controller, animated: true)
            } else {
                let masterViewController = LocalFileListTableView()
                masterViewController.fileListManager = fileListManager
                navigationController!.pushViewController(masterViewController, animated: true)
            }
        } else {
            if (indexPath.row == 0) {

                if let controller = fileListManager.getCachedController(for: URL(string: "/")!, with: .dropbox) {
                    navigationController!.pushViewController(controller, animated: true)
                } else {
                    let dropboxController = DropboxFileListTableView(style: .plain)
                    dropboxController.fileListManager = fileListManager
                    navigationController!.pushViewController(dropboxController, animated: true)
                }
            } else if indexPath.row == 1 {
                let ftpController = FTPServerPickerViewController()
                ftpController.fileListManager = fileListManager
                navigationController?.pushViewController(ftpController, animated: true)
            } else if indexPath.row == 2 {
                if !GitHubAPI.isAuthorizing {
                    let githubController = GitHubLobby(style: .grouped)
                    githubController.fileListManager = fileListManager
                    navigationController?.pushViewController(githubController, animated: true)
                }
            }

        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    deinit {
        clearNotificationHandling()
    }
}
