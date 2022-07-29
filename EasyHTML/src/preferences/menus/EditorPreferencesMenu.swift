//
//  EditorPreferencesMenu.swift
//  EasyHTML
//
//  Created by Артем on 20.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

extension String.Encoding {
    func getDescription() -> String {
        switch self {
            case String.Encoding.ascii:             return "ASCII";
            case String.Encoding.iso2022JP:         return "Japanese (ISOO 2022-JP)";
            case String.Encoding.isoLatin1:         return "Latin (ISO 8859-1)";
            case String.Encoding.isoLatin2:         return "Latin (ISO 8859-2)";
            case String.Encoding.japaneseEUC:       return "Japanese (EUC)";
            case String.Encoding.macOSRoman:        return "Mac OS Roman";
            case String.Encoding.nonLossyASCII:     return "Non-lossy ASCII";
            case String.Encoding.shiftJIS:          return "Shift JIS";
            case String.Encoding.utf16:             return "Unicode (UTF-16)";
            case String.Encoding.utf16BigEndian:    return "Unicode (UTF-16BE)";
            case String.Encoding.utf16LittleEndian: return "Unicode (UTF-16LE)";
            case String.Encoding.utf32:             return "Unicode (UTF-32)";
            case String.Encoding.utf32BigEndian:    return "Unicode (UTF-32BE)";
            case String.Encoding.utf32LittleEndian: return "Unicode (UTF-32LE)";
            case String.Encoding.utf8:              return "Unicode (UTF-8)";
            case String.Encoding.windowsCP1250:     return "Windows (CP-1250)";
            case String.Encoding.windowsCP1251:     return "Windows (CP-1251)";
            case String.Encoding.windowsCP1252:     return "Windows (CP-1252)";
            case String.Encoding.windowsCP1253:     return "Windows (CP-1253)";
            case String.Encoding.windowsCP1254:     return "Windows (CP-1254)";
            default: return "Unknown";
        }
    }
}

class EncodingOptionsViewController: AlternatingColorTableView {
    
    let encodings = [
        String.Encoding.ascii,
        String.Encoding.nonLossyASCII,
        String.Encoding.isoLatin1,
        String.Encoding.isoLatin2,
        String.Encoding.macOSRoman,
        String.Encoding.shiftJIS,
        String.Encoding.iso2022JP,
        String.Encoding.japaneseEUC,
        String.Encoding.utf8,
        String.Encoding.utf16,
        String.Encoding.utf16BigEndian,
        String.Encoding.utf16LittleEndian,
        String.Encoding.utf32,
        String.Encoding.utf32BigEndian,
        String.Encoding.utf32LittleEndian,
        String.Encoding.windowsCP1250,
        String.Encoding.windowsCP1251,
        String.Encoding.windowsCP1252,
        String.Encoding.windowsCP1253,
        String.Encoding.windowsCP1254,
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView = UITableView(frame: tableView.frame, style: .grouped)
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        title = localize("encoding", .preferences)
        updateStyle()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return localize("textsettingsdesc", .preferences)
    }
    
    var selectedIndexPath : IndexPath!
    
    func setEncoding(_ encoding: String.Encoding) {
        userPreferences.editorEncoding = encoding
        Defaults.set(encoding.rawValue, forKey: DKey.textEncoding)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if(selectedIndexPath != nil && selectedIndexPath == indexPath) {
            return
        }
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        if(selectedIndexPath != nil)
        {
            tableView.cellForRow(at: selectedIndexPath)?.accessoryType = .none
        }
        
        selectedIndexPath = indexPath
        
        setEncoding(encodings[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return encodings.count
    }
    
    private let font = UIFont.systemFont(ofSize: 14)
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let encoding = encodings[indexPath.row]
        
        cell.textLabel!.textColor = userPreferences.currentTheme.cellTextColor
        cell.textLabel!.text = encoding.getDescription()
        cell.textLabel!.font = font
        cell.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
        
        if(encoding == userPreferences.editorEncoding) {
            cell.accessoryType = .checkmark
            selectedIndexPath = indexPath
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
}

class LineEndingOptionsViewController: AlternatingColorTableView {
    override func viewDidLoad() {
        self.tableView = UITableView(frame: tableView.frame, style: .grouped)
        updateStyle()
        title = localize("lineendings", .preferences)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    let symbols = [
        LineEndingSymbol.cr,
        LineEndingSymbol.lf,
        LineEndingSymbol.crlf
    ]
    
    var selectedIndexPath : IndexPath!
    
    func setLineEndingSymbol(_ symbol: LineEndingSymbol) {
        userPreferences.lineEndingSymbol = symbol
        Defaults.set(symbol.rawValue, forKey: DKey.lineEndingSymbol)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if(selectedIndexPath != nil && selectedIndexPath == indexPath) {
            return
        }
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        if(selectedIndexPath != nil)
        {
            tableView.cellForRow(at: selectedIndexPath)?.accessoryType = .none
        }
        
        selectedIndexPath = indexPath
        
        setLineEndingSymbol(symbols[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return symbols.count
    }
    
    let font = UIFont.systemFont(ofSize: 14)
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let symbol = symbols[indexPath.row]
        
        cell.textLabel!.textColor = userPreferences.currentTheme.cellTextColor
        cell.textLabel!.text = symbol.description
        cell.textLabel!.font = font
        cell.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
        
        if(symbol == userPreferences.lineEndingSymbol) {
            cell.accessoryType = .checkmark
            selectedIndexPath = indexPath
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
}

class EditorPreferencesMenu: PreferencesMenu {
    
    var plugins = ["autoCloseBrackets","lineNumbers","matchTags","matchBrackets","autoCloseTags","foldGutter","colorpicker","lineWrapping"]
    
    let sectionheaders = ["editoroptions", "consoleoptions", "keyboardheader", "fontsize","searchsettings","textsettings", "codehighlightingpref", "helpermenu"]
    let sectionfooters = ["pluginsdescription", nil, "keyboarddarkmodewarn", "fontsizedescription", nil, "textsettingsdesc", nil, nil]
    
    var fontSizeSlider: UISlider?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SwitchCell.self, forCellReuseIdentifier: "switch")
        tableView.register(SliderCell.self, forCellReuseIdentifier: "slider")
        tableView.register(LabelCell.self, forCellReuseIdentifier: "cell")
        tableView.register(BasicCell.self, forCellReuseIdentifier: "basic")
        title = localize("editor")
        
        updateStyle()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if fontSizeSlider != nil {
            let size = fontSizeSlider!.value
            if size != userPreferences.fontSize {
                userPreferences.fontSize = fontSizeSlider!.value
                Defaults.set(userPreferences.fontSize, forKey: DKey.fontSize)
                
                Editor.sendMessageToAllEditors(message: .custom(EDITOR_UPDATE_FONT_SIZE), userInfo: nil)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 8
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0: return plugins.count + 2
        case 1, 2, 3, 4, 6, 7: return 1
        case 5: return 2
        default: return 0
        }
    }
    
    @objc func switcherUpdated(_ sender: UISwitch) {
        if(sender.tag < plugins.count) {
            updatePrefItem(id: sender.tag, value: sender.isOn)
        } else {
            if(sender.tag == plugins.count) {
                userPreferences.codeAutocompletionEnabled = sender.isOn
                Defaults.set(sender.isOn, forKey: DKey.codeAutocompletionEnabled)
            } else {
                userPreferences.emmetEnabled = sender.isOn
                Defaults.set(sender.isOn, forKey: DKey.emmetEnabledKey)
            }
        }
    }
    
    func updatePrefItem(id: Int, value: Bool) {
        let name = plugins[id]
        let index = userPreferences.enabledPlugins.firstIndex(of: name)
        
        if value {
            if index == nil {
                userPreferences.enabledPlugins.append(name)
            }
        } else {
            if index != nil {
                userPreferences.enabledPlugins.remove(at: index!)
            }
        }
        
        Defaults.set(value, forKey: "pl.\(name)")
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(indexPath.section == 5) {
            if(indexPath.row == 0) {
                navigationController!.pushViewController(EncodingOptionsViewController(), animated: true)
            } else {
                navigationController!.pushViewController(LineEndingOptionsViewController(), animated: true)
            }
        } else if indexPath.section == 6 {
            navigationController!.pushViewController(SyntaxHighlightingPreferencesMenu(), animated: true)
        } else if indexPath.section == 7 {
            navigationController!.pushViewController(ExpanderMenuPreferencesMenu(), animated: true)
        }
        if let cell = tableView.cellForRow(at: indexPath) as? SwitchCell {
            tableView.deselectRow(at: indexPath, animated: true)
            
            cell.switcher.setOn(!cell.switcher.isOn, animated: true)
            
            if indexPath.section == 0 {
                switcherUpdated(cell.switcher)
            } else if indexPath.section == 1 {
                consolePreferencesSwitchAction(cell.switcher)
            } else if indexPath.section == 4 {
                caseSensitiveSearchSliderAction(cell.switcher)
            } else if indexPath.section == 2 {
                keyboardAppearanceSwitchAction(cell.switcher)
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return localize(sectionheaders[section], .preferences)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        
        let text = sectionfooters[section]
        
        return text == nil ? nil : localize(text!, .preferences)
    }
    
    @objc func caseSensitiveSearchSliderAction(_ sender: UISwitch) {
        userPreferences.searchIsCaseSensitive = sender.isOn
        Defaults.set(userPreferences.searchIsCaseSensitive, forKey: DKey.searchIsCaseSensitive)
    }
    
    @objc func consolePreferencesSwitchAction(_ sender: UISwitch) {
        
        switch sender.tag {
        case 0:
            userPreferences.consoleShouldVanishCode = sender.isOn
            Defaults.set(sender.isOn, forKey: DKey.consoleShouldVanishCode)
            break;
        default: return
        }
    }
    
    @objc func keyboardAppearanceSwitchAction(_ sender: UISwitch) {
        userPreferences.adjustKeyboardAppearance = sender.isOn
        Defaults.set(sender.isOn, forKey: DKey.adjustKeyboardAppearance)
    }
    
    @available(iOS 13.0, *)
    @objc func updateFontSize() {
        if UIApplication.shared.openSessions.count > 1 {
            let size = fontSizeSlider!.value
            if abs(size - userPreferences.fontSize) > 1 {
                userPreferences.fontSize = fontSizeSlider!.value
                Defaults.set(userPreferences.fontSize, forKey: DKey.fontSize)
                
                Editor.sendMessageToAllEditors(message: .custom(EDITOR_UPDATE_FONT_SIZE), userInfo: nil)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            
            cell.label.font = cell.label.font.withSize(14)
            cell.switcher.tag = indexPath.row
            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            
            if cell.switcher.actions(forTarget: self, forControlEvent: .valueChanged)?.isEmpty ?? true {
                cell.switcher.addTarget(self, action: #selector(switcherUpdated(_:)), for: .valueChanged)
            }
            
            if(indexPath.row < plugins.count) {
                let key = plugins[indexPath.row]
                
                cell.label.text = localize(key, .preferences)
                cell.switcher.isOn = userPreferences.enabledPlugins.contains(key)
                
                return cell
            } else {
                let i = indexPath.row - plugins.count
                
                if i == 0 {
                    cell.label.text = localize("autocompletion_enabled")
                    cell.switcher.isOn = userPreferences.codeAutocompletionEnabled
                } else {
                    cell.label.text = "Emmet"
                    cell.switcher.isOn = userPreferences.emmetEnabled
                }
                
                return cell
            }
        } else if indexPath.section == 1 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            
            cell.label.text = localize("consoleshouldvanish", .preferences)
            cell.label.font = cell.label.font.withSize(14)
            cell.switcher.isOn = userPreferences.consoleShouldVanishCode
            cell.switcher.tag = indexPath.row
            
            if cell.switcher.actions(forTarget: self, forControlEvent: .valueChanged)?.isEmpty ?? true {
                cell.switcher.addTarget(self, action: #selector(consolePreferencesSwitchAction(_:)), for: .valueChanged)
            }
            
            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            
            return cell
            
        } else if indexPath.section == 2 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            
            cell.label.text = localize("keyboarddarkmode", .preferences)
            cell.label.font = cell.label.font.withSize(14)
            cell.switcher.isOn = userPreferences.adjustKeyboardAppearance
            cell.switcher.tag = indexPath.row
            
            if cell.switcher.actions(forTarget: self, forControlEvent: .valueChanged)?.isEmpty ?? true {
                cell.switcher.addTarget(self, action: #selector(keyboardAppearanceSwitchAction(_:)), for: .valueChanged)
            }
            
            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            
            return cell
            
        } else if indexPath.section == 3 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "slider", for: indexPath) as! SliderCell
            
            cell.slider.minimumValue = 10
            cell.slider.maximumValue = 20
            cell.slider.value = userPreferences.fontSize
            cell.slider.minimumValueImage = UIImage(named: "fontsizesmall")?.withRenderingMode(.alwaysTemplate)
            cell.slider.maximumValueImage = UIImage(named: "fontsize")?.withRenderingMode(.alwaysTemplate)
            cell.slider.setNeedsLayout()
            
            if #available(iOS 13.0, *) {
                if cell.slider.actions(forTarget: self, forControlEvent: .valueChanged)?.isEmpty ?? true {
                    cell.slider.addTarget(self, action: #selector(updateFontSize), for: .valueChanged)
                }
            }
            
            fontSizeSlider = cell.slider
            
            return cell
        } else if indexPath.section == 4 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            
            cell.label.text = localize("casesensitivesearch", .preferences)
            cell.label.font = cell.label.font.withSize(14)
            cell.switcher.isOn = userPreferences.searchIsCaseSensitive
            cell.switcher.tag = indexPath.row
            if cell.switcher.actions(forTarget: self, forControlEvent: .valueChanged)?.isEmpty ?? true {
                cell.switcher.addTarget(self, action: #selector(caseSensitiveSearchSliderAction(_:)), for: .valueChanged)
            }
            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            
            return cell
        } else if indexPath.section == 5 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! LabelCell
            
            cell.label.text = localize(indexPath.row == 0 ? "encoding" : "lineendings", .preferences)
            cell.label.font = cell.label.font.withSize(14)
            cell.rightLabel.text = indexPath.row == 0 ? userPreferences.editorEncoding.getDescription() :
                                                        userPreferences.lineEndingSymbol.description
            cell.rightLabel.font = cell.label.font.withSize(14)
            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            cell.rightLabel.textColor = userPreferences.currentTheme.secondaryTextColor
            
            cell.accessoryType = .disclosureIndicator
            
            return cell
        } else if indexPath.section == 6 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "basic") as! BasicCell
            
            cell.label.font = cell.label.font.withSize(14)
            cell.label.text = localize("codehighlightingitem", .preferences)
            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            cell.accessoryType = .disclosureIndicator
            
            return cell
        } else if indexPath.section == 7 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "basic") as! BasicCell
            
            cell.label.font = cell.label.font.withSize(14)
            cell.label.text = localize("helpermenupref", .preferences)
            cell.label.textColor = userPreferences.currentTheme.cellTextColor
            cell.accessoryType = .disclosureIndicator
            
            return cell
        }
        
        fatalError()
    }
    
}
