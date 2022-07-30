//
//  LanguagePreferencesMenu.swift
//  EasyHTML
//
//  Created by Артем on 08.03.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class LanguagePreferencesMenu: PreferencesMenu {

    private struct Language {
        let name: String
        let code: String
    }

    private let languages = [
        Language(name: "Русский", code: "ru"),
        Language(name: "English", code: "Base"),
        //Language(name: "Deutsch", code: "de")
    ]

    var selectedLanguage = ""
    var deviceLocale: String! = ""
    var bundle: Bundle! = nil

    func getBundle() {
        bundle = nil
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj") {
            bundle = Bundle(path: path)
        }

        if (bundle == nil) {
            bundle = Bundle.main
        }
    }

    func getDeviceLocale() {
        deviceLocale = NSLocale.current.languageCode

        if (deviceLocale == nil) {
            deviceLocale = "Base"
            return
        }

        for language in languages {
            if (language.code == deviceLocale) {
                return
            }
        }

        deviceLocale = "Base"
    }

    override func exit(_ sender: UIBarButtonItem) {
        if (selectedLanguage == deviceLocale) {
            Defaults.set(nil, forKey: DKey.language)
        } else {
            Defaults.set(selectedLanguage, forKey: DKey.language)
        }

        if (selectedLanguage == userPreferences.language) {
            dismiss(animated: true, completion: nil)
            return
        }

        let alert = TCAlertController.getNew()

        alert.applyDefaultTheme()

        alert.addAction(action: TCAlertAction(text: "OK", action: {
            _, _ in
            self.dismiss(animated: true, completion: nil)
        }, shouldCloseAlert: true))

        alert.contentViewHeight = 0
        alert.minimumButtonsForVerticalLayout = 0
        alert.constructView()
        alert.header.numberOfLines = 3
        alert.makeCloseableByTapOutside()
        alert.header.font = UIFont.systemFont(ofSize: 16)
        alert.headerText = NSLocalizedString("langneedtoreboot", tableName: LocalizationTable.preferences.name, bundle: bundle, value: "", comment: "")

        alert.animation = TCAnimation(animations: [.scale(0.8, 0.8), .opacity], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.6)

        view.window!.addSubview(alert.view)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = localize("language", .preferences)

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        selectedLanguage = userPreferences.language
        getBundle()
        getDeviceLocale()

        updateStyle()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func updateLanguage() {
        getBundle()
        title = NSLocalizedString("language", tableName: LocalizationTable.preferences.name, bundle: bundle, value: "", comment: "")
        navigationItem.leftBarButtonItem!.title = NSLocalizedString("ready", tableName: nil, bundle: bundle, value: "", comment: "")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let code = languages[indexPath.row].code

        if (selectedLanguage == code) {
            return
        }

        if UIDevice.current.produceSimpleHapticFeedback() {
            if #available(iOS 10.0, *) {
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()
            }
        }

        selectedLanguage = code

        updateCellColors(delay: 0)
        getBundle()
        updateLanguage()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        languages.count
    }

    private let font = UIFont.systemFont(ofSize: 14)

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        let language = languages[indexPath.row]

        cell.textLabel!.textColor = userPreferences.currentTheme.cellTextColor

        if (language.code == deviceLocale) {
            cell.textLabel!.text = language.name + " 📱"
        } else {
            cell.textLabel!.text = language.name
        }

        cell.accessoryType = language.code == selectedLanguage ? .checkmark : .none
        cell.tintColor = userPreferences.currentTheme.tabBarSelectedItemColor
        cell.textLabel!.font = font

        return cell
    }


}
