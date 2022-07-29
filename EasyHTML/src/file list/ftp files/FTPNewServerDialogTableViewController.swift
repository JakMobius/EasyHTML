//
//  FTPNewServerDialogTableViewController.swift
//  EasyHTML
//
//  Created by Артем on 16.05.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

@objc protocol FTPNewServerDialogDelegate {
    @objc optional func newServerDialog(dialog: FTPNewServerDialogTableViewController, didCreate server: FTPServer)
    @objc optional func newServerDialogDidCancel(dialog: FTPNewServerDialogTableViewController)
}

class FTPNewServerDialogTableViewController: AlternatingColorTableView, UITextFieldDelegate {

    private var readyButton: UIBarButtonItem! = nil
    internal weak var delegate: FTPNewServerDialogDelegate! = nil
    internal var sourceServer: FTPServer! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        readyButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(createServer))
        navigationItem.rightBarButtonItem = readyButton
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        
        tableView = UITableView(frame: tableView.frame, style: .grouped)
        
        title = localize("newserver", .ftp)
        
        updateStyle()
    }
    
    internal var serverIsValid: Bool {
        get {
            return nameValid && hostValid && portValid && (loginTypeIsAnonymous || loginValid)
        }
    }

    internal func checkServerValidity() -> Bool {
        var wrongIndexPath: IndexPath!
        
        if !nameValid {
            if wrongIndexPath == nil {
                wrongIndexPath = IndexPath(row: 0, section: 0)
            }
        }
        
        if !hostValid {
            if wrongIndexPath == nil {
                wrongIndexPath = IndexPath(row: 1, section: 0)
            }
        }
        
        if !portValid {
            if wrongIndexPath == nil {
                wrongIndexPath = IndexPath(row: 2, section: 0)
            }
        }
        
        if !(loginTypeIsAnonymous || loginValid) {
            if wrongIndexPath == nil {
                wrongIndexPath = IndexPath(row: 0, section: 3)
            }
        }
        
        if let indexPath = wrongIndexPath {
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
            
            var deadline: DispatchTime = .now()
            
            if self.tableView.cellForRow(at: indexPath) == nil {
                deadline = .now() + 0.35
            }
            
            DispatchQueue.main.asyncAfter(deadline: deadline) {
                [weak self] in
                if let slf = self, let cell = slf.tableView.cellForRow(at: indexPath) {
                    cell.contentView.backgroundColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 0.2978114298)
                    UIView.animate(withDuration: 1.0, animations: {
                        cell.contentView.backgroundColor = indexPath.row % 2 == 0 ?
                            userPreferences.currentTheme.cellColor1 :
                            userPreferences.currentTheme.cellColor2
                    })
                }
            }
            return false
        }
        return true
    }
    
    internal var server: FTPServer! {
        get {
            guard serverIsValid else { return nil }
            
            let name = nameCell?.input.text ?? preferredName
            var host = hostCell?.input.text ?? preferredHost
            
            if let range = host.range(of: "://") {
                host = String(host.suffix(from: range.upperBound))
            }
            
            let url = URL(string: host)!
            
            if let port = url.port {
                let string = ":\(port)"
                if host.hasSuffix(string) {
                    host = String(host.prefix(host.count - string.count))
                }
            }
            
            let port = Int(portCell?.input.text ?? preferredPort) ?? 21
            let username = loginTypeIsAnonymous ? nil : (usernameCell?.input.text ?? preferredUsername)
            let password = loginTypeIsAnonymous ? nil : (passwordCell?.input.text ?? preferredPassword)
            var path = pathCell?.input.text ?? preferredPath
            let ftpConnectionIsPassive = connectionTypeCell == nil ? false : connectionTypeCell.segmentedControl.selectedSegmentIndex == 1
            
            if !path.hasPrefix("/") {
                path = "/" + path
            }
            
            if let source = sourceServer {
                source.name = name
                source.host = host
                source.username = username
                source.password = password
                source.remotePath = path
                source.connectionType = selectedProtocol
                source.port = port
                source.ftpConnectionIsPassive = ftpConnectionIsPassive
                
                return sourceServer
            } else {
                let server = FTPServer(name: name, host: host, username: username, password: password)
                
                server.remotePath = path
                server.connectionType = selectedProtocol
                server.port = port
                server.ftpConnectionIsPassive = ftpConnectionIsPassive
                
                return server
            }
        }
    }
    
    @objc internal func createServer() {
        if checkServerValidity(), let server = server {
            dismiss(animated: true, completion: nil)
            
            delegate?.newServerDialog?(dialog: self, didCreate: server)
        }
    }
    
    var nameCell: InputCell!
    var hostCell: InputCell!
    var portCell: InputCell!
    var pathCell: InputCell!
    var usernameCell: InputCell!
    var passwordCell: InputCell!
    var connectionTypeCell: SegmentedControlCell!
    
    override func viewWillDisappear(_ animated: Bool) {
        view.endEditing(true)
    }
    
    /*override func updateTheme() {
        super.updateTheme()
         nameCell.updateKeyboardAppearance()
         hostCell.updateKeyboardAppearance()
         portCell.updateKeyboardAppearance()
         pathCell.updateKeyboardAppearance()
         usernameCell.updateKeyboardAppearance()
         passwordCell.updateKeyboardAppearance()
    }*/
    // Никогда не будет вызвано, из меню настройки
    // ftp сервера нельзя открыть настройки цветовой темы
    
    @objc internal func cancel() {
        dismiss(animated: true, completion: nil)
        
        delegate?.newServerDialogDidCancel?(dialog: self)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return ""
        case 1: return localize("serverprotocol", .ftp)
        case 2: return localize("serverlogintype", .ftp)
        case 4: return selectedProtocol == .ftp ? localize("connectiontype", .ftp) : nil
        default: return ""
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0: return 4
        case 1: return 2
        case 2: return 2
        case 3: return loginTypeIsAnonymous ? 0 : 2
        case 4: return selectedProtocol == .ftp ? 1 : 0
        default: return 0
        }
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                selectedProtocol = .ftp
                tableView.cellForRow(at: IndexPath(row: 1, section: 1))?.accessoryType = .none
                tableView.reloadSections(IndexSet(integer: 4), with: .fade)
            } else if indexPath.row == 1 {
                selectedProtocol = .sftp
                tableView.cellForRow(at: IndexPath(row: 0, section: 1))?.accessoryType = .none
                tableView.reloadSections(IndexSet(integer: 4), with: .fade)
            }
            
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            
        } else if indexPath.section == 2 {
            
            if (indexPath.row == 0) == loginTypeIsAnonymous {
                return
            }
            
            loginTypeIsAnonymous = !loginTypeIsAnonymous
            
            if loginTypeIsAnonymous {
                tableView.cellForRow(at: IndexPath(row: 1, section: 2))?.accessoryType = .none
                tableView.reloadSections(IndexSet(integer: 3), with: .fade)
            } else {
                tableView.cellForRow(at: IndexPath(row: 0, section: 2))?.accessoryType = .none
                tableView.reloadSections(IndexSet(integer: 3), with: .fade)
                usernameChanged()
            }
            
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section < 1 || indexPath.section > 2 {
            return nil
        }
        
        return indexPath
    }
    
    internal func getInputCell() -> InputCell {
        let cell = InputCell()
        
        let font = UIFont.systemFont(ofSize: 14)
        
        cell.label.font = font
        cell.input.font = font
        cell.input.delegate = self
        cell.label.textColor = userPreferences.currentTheme.cellTextColor
        cell.input.textColor = userPreferences.currentTheme.cellTextColor
        
        if #available(iOS 11.0, *) {
            cell.input.smartDashesType = .no
            cell.input.smartDashesType = .no
            cell.input.smartInsertDeleteType = .no
        }
        
        cell.input.autocorrectionType = .no
        cell.input.autocapitalizationType = .none
        cell.input.returnKeyType = .done
        cell.input.spellCheckingType = .no
        
        
        return cell
    }
    
    internal func getBasicCell() -> UITableViewCell {
        let cell = UITableViewCell()
        
        cell.textLabel!.textColor = userPreferences.currentTheme.cellTextColor
        
        return cell
    }
    
    internal var selectedProtocol: FTPServer.ConnectionProtocol = .ftp
    internal var loginTypeIsAnonymous = false
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if(section == 4 && loginTypeIsAnonymous) {
            return CGFloat.leastNonzeroMagnitude
        }
        if(section == 5 && selectedProtocol == .ftp) {
            return CGFloat.leastNonzeroMagnitude
        }
        
        return 40
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                
                if nameCell == nil {
                    nameCell = getInputCell()
                    nameCell.label.text = localize("servername", .ftp)
                    nameCell.input.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
                    nameCell.input.text = preferredName
                }
                
                return nameCell
                
            } else if indexPath.row == 1 {
                if hostCell == nil {
                    hostCell = getInputCell()
                    hostCell.label.text = localize("serverhost", .ftp)
                    hostCell.input.attributedPlaceholder = NSAttributedString(
                        string: "example.com",
                        attributes: [
                            .foregroundColor : userPreferences.currentTheme.secondaryTextColor
                        ]
                    )
                    hostCell.input.addTarget(self, action: #selector(hostChanged), for: .editingChanged)
                    hostCell.input.text = preferredHost
                }
                
                return hostCell
            } else if indexPath.row == 2 {
                if portCell == nil {
                    portCell = getInputCell()
                    portCell.label.text = localize("serverport", .ftp)
                    portCell.input.attributedPlaceholder = NSAttributedString(
                        string: "21",
                        attributes: [
                            .foregroundColor : userPreferences.currentTheme.secondaryTextColor
                        ]
                    )
                    portCell.input.addTarget(self, action: #selector(portChanged), for: .editingChanged)
                    portCell.input.keyboardType = .numberPad
                    portCell.input.text = preferredPort
                }
                
                return portCell
            } else {
                if pathCell == nil {
                    pathCell = getInputCell()
                    pathCell.label.text = localize("serverremotepath", .ftp)
                    pathCell.input.attributedPlaceholder = NSAttributedString(
                        string: "/",
                        attributes: [
                            .foregroundColor : userPreferences.currentTheme.secondaryTextColor
                        ]
                    )
                    pathCell.input.text = preferredPath
                }
                
                return pathCell
            }
        case 1:
            let cell = getBasicCell()
            cell.textLabel!.font = UIFont.systemFont(ofSize: 14)
            if indexPath.row == 0 {
                cell.textLabel!.text = "FTP"
                cell.accessoryType = selectedProtocol == .ftp ? .checkmark : .none
            } else {
                cell.textLabel!.text = "SFTP"
                cell.accessoryType = selectedProtocol == .sftp ? .checkmark : .none
            }
            
            cell.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
            
            return cell
        case 2:
            let cell = getBasicCell()
            cell.textLabel!.font = UIFont.systemFont(ofSize: 14)
            if indexPath.row == 0 {
                cell.textLabel!.text = localize("logintypeanonymous", .ftp)
                cell.accessoryType = loginTypeIsAnonymous ? .checkmark : .none
            } else {
                cell.textLabel!.text = localize("logintypenormal", .ftp)
                cell.accessoryType = loginTypeIsAnonymous ? .none : .checkmark
            }
            
            cell.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
            
            return cell
        case 3:
            
            if indexPath.row == 0 {
                if usernameCell == nil {
                    usernameCell = getInputCell()
                    usernameCell.label.text = localize("serverlogin", .ftp)
                    usernameCell.input.addTarget(self, action: #selector(usernameChanged), for: .editingChanged)
                    usernameCell.input.text = preferredUsername
                }
                
                return usernameCell
                
            } else {
                if passwordCell == nil {
                    passwordCell = getInputCell()
                    passwordCell.label.text = localize("serverpassword", .ftp)
                    passwordCell.input.isSecureTextEntry = true
                    passwordCell.input.text = preferredPassword
                }
                
                return passwordCell
            }
        case 4:
            
            if connectionTypeCell == nil {
                connectionTypeCell = SegmentedControlCell()
                
                connectionTypeCell.segmentedControl.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
                connectionTypeCell.segmentedControl.insertSegment(withTitle: localize("connectiontypeactive", .ftp), at: 0, animated: false)
                connectionTypeCell.segmentedControl.insertSegment(withTitle: localize("connectiontypepassive", .ftp), at: 1, animated: false)
                connectionTypeCell.segmentedControl.selectedSegmentIndex = preferringPassiveConnectionType ? 1 : 0
            }
            
            return connectionTypeCell
        default: return UITableViewCell()
        }
    }
    
    internal var preferredHost = ""
    internal var preferredUsername = ""
    internal var preferredPassword = ""
    internal var preferredPath = ""
    internal var preferredName = ""
    internal var preferredPort = ""
    internal var preferringPassiveConnectionType = false
    
    internal var nameValid: Bool = false
    internal var hostValid: Bool = false
    internal var portValid: Bool = true
    internal var loginValid: Bool = false
    
    @objc internal func nameChanged() {
        
        nameValid = false
        
        guard let cell = nameCell else { return }
        guard let text = cell.input.text else { return }
        guard !text.isEmpty else { return }
        guard text.count < 32 else { return }
        
        nameValid = true
    }
    
    @objc internal func hostChanged() {
        hostValid = false
        
        guard let cell = hostCell else { return }
        guard var text = cell.input.text else { return }
        guard !text.isEmpty else { return }
        
        if selectedProtocol == .ftp {
            if !text.hasPrefix("ftp://") {
                text = "ftp://" + text
            }
        } else {
            if !text.hasPrefix("sftp://") {
                text = "sftp://" + text
            }
        }
        
        guard let url = URL(string: text) else { return }
        guard url.user == nil && url.password == nil else { return }
        guard url.host != nil else { return }
        guard url.pathComponents.count <= 1 else { return }
        
        if let port = url.port {
            portCell?.input.isEnabled = false
            portCell?.input.text = String(port)
            portCell?.alpha = 0.5
        } else {
            if let cell = portCell, !cell.input.isEnabled {
                cell.input.isEnabled = true
                cell.alpha = 1.0
                cell.input.text = ""
            }
        }
        
        hostValid = true
    }
    
    @objc internal func portChanged() {
        portValid = false
        
        guard let cell = portCell else { return }
        guard let text = cell.input.text, !text.isEmpty else { portValid = true; return }
        guard let port = Int(text) else { return }
        guard port > 0 else { return }
        
        portValid = true
    }
    
    @objc internal func usernameChanged() {
        loginValid = false
        
        guard let cell = usernameCell else { return }
        guard cell.input.hasText else { return }
        
        loginValid = true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
