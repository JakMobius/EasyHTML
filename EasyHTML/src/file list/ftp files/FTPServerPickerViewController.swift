//
//  FTPServerPickerViewController.swift
//  EasyHTML
//
//  Created by Артем on 14.05.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

internal class FTPServerPickerViewController: BasicMasterController, FTPNewServerDialogDelegate {
    
    internal var fileListManager: FileListManager! = nil
    internal var servers: [FTPServer] = []
    
    override func updateTheme() {
        
        super.updateTheme()
        view.backgroundColor = userPreferences.currentTheme.background
        noServersTopLabel?.textColor = userPreferences.currentTheme.secondaryTextColor
        updateToolBar()
    }
    
    internal override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "FTP";
        
        tableView.register(UINib(nibName: "FileListCell", bundle: nil), forCellReuseIdentifier: "cell")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewServer))
        
        setupToolBar()
        updateStyle()
        readServers()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        
        if servers.isEmpty {
            showNoServersWarning()
        }
        
        setupThemeChangedNotificationHandling()
        
        edgesForExtendedLayout = []
    }
    
    @objc internal func addNewServer() {
        let controller = FTPNewServerDialogTableViewController()
        let nc = ThemeColoredNavigationController(rootViewController: controller)
        
        nc.modalPresentationStyle = .formSheet
        controller.delegate = self
        
        view.window!.rootViewController!.present(nc, animated: true, completion: nil)
    }
    
    internal override func viewDidDisappear(_ animated: Bool) {
        
        let nsarray = NSArray(array: servers)
        
        let data = NSKeyedArchiver.archivedData(withRootObject: nsarray)
    
        Defaults.set(data, forKey: "ftpservers")
    }
    
    internal func showDeletionAlert(indexPath: IndexPath) {
        
        func delete(action: UIAlertAction) {
            servers[indexPath.row].password = nil
            servers.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
            
            if servers.isEmpty {
                showNoServersWarning()
            }
        }
        
        let title = localize("serverdeletealert", .ftp)
        
        let deleteAlert = UIAlertController(title: title, message: localize("cannotbeundone"), preferredStyle: .actionSheet)
        deleteAlert.addAction(UIAlertAction(title: localize("delete"), style: .destructive, handler:delete))
        deleteAlert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler:nil))
        
        let cell = tableView.cellForRow(at: indexPath)
        
        deleteAlert.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: cell!.bounds.origin.x + cell!.bounds.width, y: cell!.bounds.origin.y+20), size: CGSize(width: 50, height: 30))
        deleteAlert.popoverPresentationController?.sourceView = cell?.contentView
        
        view.window!.rootViewController!.present(deleteAlert, animated: true, completion: nil)
    }
    
    internal override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            showDeletionAlert(indexPath: indexPath)
        }
    }
    
    internal func showDetailController(for server: FTPServer) {
        let controller = FTPServerDetailViewController()
        let nc = ThemeColoredNavigationController(rootViewController: controller)
        
        nc.modalPresentationStyle = .formSheet
        controller.delegate = self
        controller.sourceServer = server
        
        view.window!.rootViewController!.present(nc, animated: true, completion: nil)
    }
    
    @objc func detailButtonTapped(_ sender: UIButton) {
        showDetailController(for: servers[sender.tag])
    }
    
    internal func readServers() {
        
        if let data = Defaults.defaults.data(forKey: "ftpservers"),
            let servers = NSKeyedUnarchiver.unarchiveObject(with: data) as? [FTPServer] {
            
            self.servers = servers
        } else {
            servers = []
        }
    }
    
    internal override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    internal override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return servers.count
    }
    
    internal func openServer(at index: Int) {
        let server = servers[index]
        let url = URL(string: server.remotePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        
        if let controller = fileListManager.getCachedController(for: url, with: .ftp(server: server)) {
            navigationController!.pushViewController(controller, animated: true)
            return
        }
        
        let session = server.createSession()
        
        let controller = FTPFileListTableView()
        controller.session = session
        controller.fileListManager = fileListManager
        controller.title = server.name
        controller.url = url
        controller.server = server
        controller.isRoot = true
        
        navigationController?.pushViewController(controller, animated: true)
    }
    
    internal override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        openServer(at: indexPath.row)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    internal override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! FileListCell
        let server = servers[indexPath.row]
        
        cell.title.text = server.name
        cell.detailLabel.text = server.host
        cell.title.textColor = userPreferences.currentTheme.cellTextColor
        
        if userPreferences.currentTheme.isDark {
            cell.cellImage.image = #imageLiteral(resourceName: "server").invertedImage()
        } else {
            cell.cellImage.image = #imageLiteral(resourceName: "server")
        }
        
        // При использовании accessoryType detail-кнопка не реагирует на нажатия почему-то...
        // Так что костылим.
        
        let button = UIButton(type: .detailDisclosure)
        button.tintColor = userPreferences.currentTheme.detailDisclosureButtonColor
        button.tag = indexPath.row
        button.addTarget(self, action: #selector(detailButtonTapped(_:)), for: .touchUpInside)
        cell.accessoryView = button
        
        return cell
    }
    
    func newServerDialog(dialog: FTPNewServerDialogTableViewController, didCreate server: FTPServer) {
        if dialog is FTPServerDetailViewController {
            
            // Сервер редактируется самим контроллером. Просто перезагружаем тэйбл
            
            tableView.reloadData()
        } else {
            servers.append(server)
            tableView.reloadSections(IndexSet(integer: 0), with: .fade)
            
            hideNoServersWarning()
        }
    }
    
    private var noServersTopLabel: UILabel! = nil
    private var noServersBottomLabel: UILabel! = nil
    
    internal override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        if noServersWarningShown {
            
            var transformTop = scrollView.contentOffset.y * 0.4
            let transformBottom = scrollView.contentOffset.y * 0.25
            
            let delta = transformTop - transformBottom
            
            if delta >= 15 {
                transformTop -= delta - 15
            }
            
            noServersTopLabel?.transform = CGAffineTransform(translationX: 0, y: transformTop)
            noServersBottomLabel?.transform = CGAffineTransform(translationX: 0, y: transformBottom)
        }
    }
    
    internal var noServersWarningShown: Bool {
        get {
            return noServersTopLabel != nil
        }
    }
    
    internal func showNoServersWarning() {
        if noServersTopLabel == nil && noServersBottomLabel == nil {
            noServersTopLabel = UILabel()
            noServersBottomLabel = UILabel()
            
            noServersTopLabel.translatesAutoresizingMaskIntoConstraints = false
            noServersBottomLabel.translatesAutoresizingMaskIntoConstraints = false
            
            noServersTopLabel.textAlignment = .center
            noServersBottomLabel.textAlignment = .center
            
            view.addSubview(noServersTopLabel)
            view.addSubview(noServersBottomLabel)
            
            tableView.centerXAnchor.constraint(equalTo: noServersTopLabel.centerXAnchor).isActive = true
            tableView.centerYAnchor.constraint(equalTo: noServersTopLabel.centerYAnchor, constant: 60).isActive = true
            noServersTopLabel.widthAnchor.constraint(lessThanOrEqualTo: tableView.widthAnchor, constant: -100).isActive = true
            
            tableView.centerXAnchor.constraint(equalTo: noServersBottomLabel.centerXAnchor).isActive = true
            noServersBottomLabel.topAnchor.constraint(equalTo: noServersTopLabel.bottomAnchor, constant: 20).isActive = true
            noServersBottomLabel.widthAnchor.constraint(lessThanOrEqualTo: tableView.widthAnchor, constant: -100).isActive = true
            noServersTopLabel.bottomAnchor.constraint(equalTo: tableView.bottomAnchor).isActive = true
            
            noServersTopLabel.text = localize("noservers", .ftp)
            noServersTopLabel.textColor = userPreferences.currentTheme.secondaryTextColor
            noServersTopLabel.font = .systemFont(ofSize: 25)
            noServersBottomLabel.text = localize("noservershint", .ftp)
            noServersBottomLabel.textColor = .gray
            noServersBottomLabel.numberOfLines = 0
            noServersBottomLabel.font = .systemFont(ofSize: 15)
            
            noServersBottomLabel.alpha = 0
            noServersTopLabel.alpha = 0
            
            noServersBottomLabel.transform = CGAffineTransform(translationX: 0, y: 20)
            noServersTopLabel.transform = CGAffineTransform(translationX: 0, y: 20)
            
            UIView.animate(withDuration: 0.5, delay: 0.2, options: [.curveEaseOut], animations: {
                self.noServersTopLabel.alpha = 1.0
                self.noServersTopLabel.transform = .identity
            }, completion: nil)
            UIView.animate(withDuration: 0.5, delay: 0.4, options: [.curveEaseOut], animations: {
                self.noServersBottomLabel.alpha = 1.0
                self.noServersBottomLabel.transform = .identity
            }, completion: nil)
        }
    }
    
    internal func hideNoServersWarning() {
        
        guard let topLabel = self.noServersTopLabel else {return}
        self.noServersTopLabel = nil
        
        guard let bottomLabel = self.noServersBottomLabel else {return}
        self.noServersBottomLabel = nil
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveEaseIn], animations: {
            topLabel.alpha = 0.0
            topLabel.transform = topLabel.transform.translatedBy(x: 0, y: -20)
        }, completion: nil)
        UIView.animate(withDuration: 0.5, delay: 0.2, options: [.curveEaseIn], animations: {
            bottomLabel.alpha = 0.0
            bottomLabel.transform = topLabel.transform.translatedBy(x: 0, y: -20)
        }, completion: {
            _ in
            // topLabel убирается именно в этом completion-методе, так, как если
            // убрать его раньше, то сбивается layout для bottomLabel, так, как
            // он построен частично на позиции topLabel
            
            topLabel.removeFromSuperview()
            bottomLabel.removeFromSuperview()
        })
    }
    
    deinit {
        clearNotificationHandling()
    }
}
