//
//  ArchiveDialogTableViewController.swift
//  EasyHTML
//
//  Created by Артем on 18.02.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit
import Zip

class ArchiveDialogPasswordCell: UITableViewCell {
    var field = UITextField()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        field.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(field);

        field.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 7).isActive = true
        field.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -7).isActive = true
        field.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        field.heightAnchor.constraint(equalToConstant: 30).isActive = true

        field.attributedPlaceholder = NSAttributedString(string: localize("password"), attributes: [NSAttributedString.Key.foregroundColor: userPreferences.currentTheme.secondaryTextColor])
        field.textColor = userPreferences.currentTheme.cellTextColor
        field.layer.borderColor = userPreferences.currentTheme.tableViewDelimiterColor.cgColor
        field.layer.borderWidth = 1.0
        field.layer.masksToBounds = true
        field.layer.cornerRadius = 3.0
        field.setLeftPaddingPoints(6.0)
        field.isSecureTextEntry = true
        field.placeholder = localize("passwordoptional")
        field.returnKeyType = .done
        field.font = UIFont.systemFont(ofSize: 14)

        if #available(iOS 11.0, *) {
            field.smartDashesType = .no
            field.smartQuotesType = .no
            field.smartInsertDeleteType = .no
        }

        field.autocorrectionType = .no
        field.autocapitalizationType = .none
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

internal protocol ArchiveDialogDelegate: AnyObject {
    func archiveDialog(dialog controller: ArchiveDialogTableViewController, shouldArchive file: FSNode, with options: ArchivingOptions)
}

internal class ArchiveDialogTableViewController: AlternatingColorTableView, UITextFieldDelegate {

    internal weak var delegate: ArchiveDialogDelegate? = nil
    internal var file: FSNode! = nil

    internal override func viewDidLoad() {
        super.viewDidLoad()

        title = localize("archiving")

        tableView = UITableView(frame: tableView.frame, style: .grouped)

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(ArchiveDialogPasswordCell.self, forCellReuseIdentifier: "password")

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: localize("beginarchiving"), style: .done, target: self, action: #selector(archive))

        updateStyle()
    }

    @objc func archive() {
        let options = ArchivingOptions()
        options.compressionType = compressionType
        options.password = passwordField?.text!

        delegate?.archiveDialog(dialog: self, shouldArchive: file, with: options)
        //fileBrowser.controller.zipFile(fileName: fileBrowser.fileName, compression: compressionType, password: passwordField!.text!, from: self, completion: {
        //    self.navigationController?.dismiss(animated: true, completion: nil)
        //})
    }

    override internal func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0) {
            return localize("compressiontype")
        }

        return ""
    }

    override internal func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return localize("zippasswordwarning")
        }
        return ""
    }

    override internal func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 4 : 1
    }

    var passwordField: UITextField? = nil
    var compressionType = ZipCompression.bestCompression

    override internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.section == 0) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

            cell.textLabel!.text = localize(ZipCompression.init(rawValue: indexPath.row)!.localizedDescription())
            if (indexPath.row == compressionType.rawValue) {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }

            cell.textLabel!.textColor = userPreferences.currentTheme.cellTextColor
            cell.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "password", for: indexPath) as! ArchiveDialogPasswordCell

            passwordField = cell.field
            passwordField?.delegate = self

            return cell
        }
    }

    override internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath.section == 0) {
            if (indexPath.row != compressionType.rawValue) {
                let oldSelection = compressionType.rawValue
                compressionType = ZipCompression.init(rawValue: indexPath.row)!
                tableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0), IndexPath(row: oldSelection, section: 0)], with: .fade)
            }
        } else {

        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    internal func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        userPreferences.currentTheme.statusBarStyle
    }
}
