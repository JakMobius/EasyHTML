//
//  SyntaxHighlightingPreferencesMenu.swift
//  EasyHTML
//
//  Created by Артем on 24.06.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

struct SyntaxHighlightScheme {
    
    typealias SerializedType = [Any]
    
    func serialize() -> SerializedType {
        return [ext, mode.cmMimeType, mode.configurationFiles, mode.description]
    }
    
    static func deserialize(type: SerializedType) -> SyntaxHighlightScheme? {
        guard type.count == 4 else { return nil }
        
        guard let ext = type[0] as? String else { return nil }
        guard let mime = type[1] as? String else { return nil }
        guard let files = type[2] as? [String] else { return nil }
        guard let desc = type[3] as? String else { return nil }
        
        return SyntaxHighlightScheme(ext: ext, mode: Mode(mime, files: files, desc: desc))
    }
    
    struct Mode {
        var cmMimeType: String
        var configurationFiles: [String]
        var description: String
        
        init(_ mime: String, files: [String], desc: String) {
            self.cmMimeType = mime
            self.configurationFiles = files
            self.description = desc
        }
        
        static var php =        Mode("application/x-httpd-php", files: ["html", "xml", "js", "css", "clike", "php"], desc: "PHP")
        static var html =       Mode("text/html",               files: ["html", "xml", "js", "css"],                 desc: "HTML")
        static var json =       Mode("application/ld+json",     files: ["js"],                                       desc: "JSON")
        // Перфекционизм. *Facepalm*
        static var javascript = Mode("text/javascript",   files: ["js"],       desc: "JavaScript")
        static var css =        Mode("text/css",          files: ["css"],      desc: "CSS")
        static var scss =       Mode("text/x-scss",       files: ["css"],      desc: "SCSS")
        static var xml =        Mode("text/xml",          files: ["xml"],      desc: "XML")
        static var java =       Mode("text/x-java",       files: ["clike"],    desc: "Java")
        static var objectivec = Mode("text/x-objectivec", files: ["clike"],    desc: "Objective-C")
        static var scala =      Mode("text/x-scala",      files: ["clike"],    desc: "Scala")
        static var c =          Mode("text/x-csrc",       files: ["clike"],    desc: "C")
        static var cpp =        Mode("text/x-c++src",     files: ["clike"],    desc: "C++")
        static var csharp =     Mode("text/x-csharp",     files: ["clike"],    desc: "C#")
        static var swift =      Mode("text/x-swift",      files: ["swift"],    desc: "Swift")
        static var python =     Mode("text/x-python",     files: ["python"],   desc: "Python")
        static var pascal =     Mode("text/x-pascal",     files: ["pascal"],   desc: "Pascal")
        static var lua =        Mode("text/x-lua",        files: ["lua"],      desc: "Lua")
        static var markdown =   Mode("text/x-markdown",   files: ["markdown"], desc: "Markdown")
        static var fortran =    Mode("text/x-fortran",    files: ["fortran"],  desc: "Fortran")
        static var fsharp =     Mode("text/x-fsharp",     files: ["milike"],   desc: "F#")
        static var ocaml =      Mode("text/x-ocaml",      files: ["milike"],   desc: "OCaml")
        static var mysql =      Mode("text/x-mysql",      files: ["sql"],      desc: "MySQL")
        static var mariadb =    Mode("text/x-mariadb",    files: ["sql"],      desc: "MariaDB")
        static var hive =       Mode("text/x-hive",       files: ["sql"],      desc: "Hive")
        static var cassandra =  Mode("text/x-cassandra",  files: ["sql"],      desc: "Cassandra")
        static var txt =        Mode("text/plain",        files: [],           desc: "Plain text")
        
        static var allModes = [c, cpp, csharp, css, fortran, fsharp, html, java, javascript, json, lua, markdown, objectivec, ocaml, pascal, php, python, scala, scss, swift, txt, xml, mysql, mariadb, hive, cassandra]
    }
    
    var ext: String
    var mode: Mode
}

class SyntaxHighlightingPreferencesMenu: AlternatingColorTableView, SyntaxHighlightingPickerDelegate, SyntaxHighlightSchemeCreationDialogDelegate {
    
    func syntaxHighlightSchemeDialog(createSchemeWith ext: String) {
        userPreferences.syntaxHighlightingConfiguration.insert(SyntaxHighlightScheme(ext: ext, mode: .txt), at: 0)
        tableView.insertRows(at: [IndexPath(row: 0, section: 1)], with: .fade)
        
        needsReSave = true
        
        updateCellColors()
    }
    
    func syntaxHighlightingPicker(_ picker: SyntaxHighlightingPicker, didSelect type: SyntaxHighlightScheme.Mode) {
        userPreferences.syntaxHighlightingConfiguration[editingTypeIndex].mode = type
        tableView.reloadRows(at: [IndexPath(row: editingTypeIndex, section: 1)], with: .none)
        
        needsReSave = true
    }
    
    override func viewDidLoad() {
        
        tableView = UITableView(frame: tableView.frame, style: .grouped)
        
        title = localize("codehighlightingpref", .preferences)
        
        tableView.register(SwitchCell.self, forCellReuseIdentifier: "switch")
        tableView.register(LabelCell.self, forCellReuseIdentifier: "label")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewScheme))
        
        updateStyle()
    }
    
    @objc func addNewScheme() {
        let dialog = SyntaxHighlightSchemeCreationDialog()
        dialog.delegate = self
        
        view.window!.addSubview(dialog.alert.view)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return userPreferences.syntaxHighlightingEnabled ? 2 : 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 1 ? localize("codehighlightingconf", .preferences) : nil
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return userPreferences.syntaxHighlightingConfiguration.count
        }
    }
    
    var editingTypeIndex: Int!
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            guard let cell = tableView.cellForRow(at: indexPath) as? SwitchCell else { return }
            
            cell.switcher.setOn(!cell.switcher.isOn, animated: true)
            
            userPreferences.syntaxHighlightingEnabled = cell.switcher.isOn
            
            if userPreferences.syntaxHighlightingEnabled {
                tableView.insertSections(IndexSet(integer: 1), with: .fade)
            } else {
                tableView.deleteSections(IndexSet(integer: 1), with: .fade)
            }
            
        } else {
            let controller = SyntaxHighlightingPicker()
            controller.delegate = self
            controller.selectedType = userPreferences.syntaxHighlightingConfiguration[indexPath.row].mode
            editingTypeIndex = indexPath.row
            navigationController!.pushViewController(controller, animated: true)
        }
    }
    
    @objc func toggleSyntaxHighlighting(_ sender: UISwitch) {
        userPreferences.syntaxHighlightingEnabled = sender.isOn
        
        if userPreferences.syntaxHighlightingEnabled {
            tableView.insertSections(IndexSet(integer: 1), with: .fade)
        } else {
            tableView.deleteSections(IndexSet(integer: 1), with: .fade)
        }
        
        Defaults.set(sender.isOn, forKey: DKey.syntaxHighlightingEnabled)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            
            cell.switcher.isOn = userPreferences.syntaxHighlightingEnabled
            
            cell.label.font = .systemFont(ofSize: 13)
            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            
            cell.label.text = localize("codehighlightingpref", .preferences)
            
            if cell.switcher.actions(forTarget: self, forControlEvent: .valueChanged)?.isEmpty ?? true {
                cell.switcher.addTarget(self, action: #selector(toggleSyntaxHighlighting(_:)), for: .valueChanged)
            }
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "label", for: indexPath) as! LabelCell
            
            let mode = userPreferences.syntaxHighlightingConfiguration[indexPath.row]
            
            let attributedText = NSMutableAttributedString(string: "*.", attributes: [.foregroundColor : UIColor.lightGray])
            
            attributedText.append(NSAttributedString(string: mode.ext, attributes: [
                .foregroundColor : userPreferences.currentTheme.cellTextColor
            ]))
            
            cell.label.attributedText = attributedText
            
            cell.label.font = .systemFont(ofSize: 14)
            cell.rightLabel.font = .systemFont(ofSize: 13)
            
            cell.rightLabel.text = mode.mode.description
            cell.rightLabel.textColor = userPreferences.currentTheme.cellTextColor
            
            cell.accessoryType = .disclosureIndicator
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1
    }
    
    var needsReSave = false
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            userPreferences.syntaxHighlightingConfiguration.remove(at: indexPath.row)
            
            tableView.deleteRows(at: [indexPath], with: .left)
            
            updateCellColors()
            
            needsReSave = true
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        guard needsReSave else { return }
        
        var serialized = [SyntaxHighlightScheme.SerializedType]()
        
        for scheme in userPreferences.syntaxHighlightingConfiguration {
            serialized.append(scheme.serialize())
        }
        
        Defaults.set(serialized, forKey: DKey.syntaxHighlightingConfiguration)
    }
    
}

protocol SyntaxHighlightSchemeCreationDialogDelegate: AnyObject {
    func syntaxHighlightSchemeDialog(createSchemeWith ext: String)
}

class SyntaxHighlightSchemeCreationDialog: NSObject {
    internal let alert: TCAlertController
    internal var textField: UITextField!
    private var activityIndicator: UIActivityIndicatorView! = nil
    weak var delegate: SyntaxHighlightSchemeCreationDialogDelegate! = nil
    
    private func setupTextField() {
        textField = alert.addTextField()
        
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        
        if #available(iOS 11.0, *) {
            textField.smartInsertDeleteType = .no
            textField.smartDashesType = .no
            textField.smartQuotesType = .no
        }
        
        textField.returnKeyType = .done
        textField.placeholder = localize("fileextension", .preferences)
    }
    
    internal override init() {
        
        alert = TCAlertController.getNew()
        
        super.init()
        
        let header = localize("newsyntaxhighlightingscheme", .preferences)
        
        alert.applyDefaultTheme()
        
        alert.contentViewHeight = 30.0
        alert.constructView()
        alert.headerText = header
        alert.makeCloseableByTapOutside()
        setupTextField()
        
        alert.addAction(action: TCAlertAction(text: localize("createsyntaxhighlightingscheme", .preferences), action: {
            _, _ in
            self.textField.selectedTextRange = nil
            self.create()
        }))
        alert.addAction(action: TCAlertAction(text: localize("cancel"), shouldCloseAlert: true))
        
        activityIndicator = alert.addActivityIndicator(offset: CGPoint(x: 0, y: -6 ))
        alert.contentView.addSubview(textField)
        
        alert.animation = TCAnimation(animations: [TCAnimationType.scale(0.8, 0.8)], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.5)
    }
    
    private var task: DispatchWorkItem? = nil
    
    private func create() {
        var ext = textField.text!
        
        if ext.hasPrefix(".") {
            ext.remove(at: ext.startIndex)
        }
        
        while ext.hasSuffix(" ") {
            ext.remove(at: ext.endIndex)
        }
        
        textField.isHidden = true
        activityIndicator.startAnimating()
        
        var result: FileCreationResult
        
        if ext.contains(".") || ext.count == 0 || ext.count > 15 {
            result = .wrongName
        } else {
            result = .success
        }
        
        if result == .success {
            
            delegate?.syntaxHighlightSchemeDialog(createSchemeWith: ext.lowercased())
            
            alert.translateTo(animation: TCAnimation(animations: [.opacity]), completion: {
                _ in
                self.alert.dismissAllAlertControllers()
            })
        } else {
            alert.buttons[0].isEnabled = true
            alert.buttons[1].isEnabled = true
            textField.isHidden = false
            activityIndicator.stopAnimating()
            
            self.alert.header.text = result.description
            let prevcolor = textField.layer.borderColor
            let animation: CABasicAnimation = CABasicAnimation(keyPath: "borderColor")
            animation.toValue = prevcolor
            animation.fromValue = UIColor.red.cgColor
            animation.duration = 1.0
            animation.isRemovedOnCompletion = false
            textField.layer.add(animation, forKey: "borderColor")
            
            task?.cancel()
            
            let when = DispatchTime.now() + 1
            task = DispatchWorkItem {
                self.task = nil
                self.alert.header.setTextWithFadeAnimation(text: localize("newsyntaxhighlightingscheme", .preferences))
            }
            DispatchQueue.main.asyncAfter(deadline: when, execute: task!)
            
            return
        }
    }
}
