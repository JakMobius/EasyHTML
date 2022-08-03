//
//  UserPreferences.swift
//  EasyHTML
//
//  Created by Артем on 11.10.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import Foundation
import UIKit

internal enum LineEndingSymbol: Int8 {
    case cr = 0,
         lf = 1,
         crlf = 2;

    internal var symbol: String {
        get {
            switch self {
            case .cr: return "\r"
            case .lf: return "\n"
            case .crlf: return "\r\n"
            }
        }
    }

    internal var description: String {
        get {
            switch self {
            case .cr: return "CR (Macintosh)"
            case .lf: return "LF (Unix)"
            case .crlf: return "CR LF (Windows)"
            }
        }
    }
}

internal class DKey {
    internal static var fontSize = "fontSize"
    internal static var enabledPlugins = "plugins"
    internal static var theme = "theme"
    internal static var sortingType = "sortingType"
    internal static var language = "language"
    internal static var searchIsCaseSensitive = "casesensitivesearch"
    internal static var hapticFeedbackEnabled = "hapticFeedback"
    internal static var textEncoding = "textEncoding"
    internal static var lineEndingSymbol = "lineEndingSymbol"
    internal static var statistics = "statistics"
    internal static var syntaxHighlightingEnabled = "syntaxHighlightingEnabled"
    internal static var syntaxHighlightingConfiguration = "syntaxHighlightingConfig"
    internal static var consoleShouldVanishCode = "vanishConsole"
    internal static var codeAutocompletionEnabled = "autocompletionEnabled"
    internal static var lastInstalledVersion = "lastVersion"
    internal static var emmetEnabledKey = "emmetEnabled"
    internal static var adjustKeyboardAppearance = "adjustKeyboardAppearance"
    internal static var expanderConfig = "expanderConfig"
    internal static var githubRecent = "githubRecent"
}


internal struct UserStatistics {

    var installVersion: String
    var installDate: Date
    var symbolsWrittenTotal: Int
    var filesCreated: Int
    var filesDeleted: Int
    var filesOpened: Int
    var foldersCreated: Int
    var foldersDeleted: Int

    init() {

        let statistics = Defaults.object(forKey: DKey.statistics) as? NSDictionary

        let installVersion = statistics?["installVersion"] as? String
        let installDate = statistics?["installDate"] as? Double
        let symbolsWrittenTotal = statistics?["symbolsWrittenTotal"] as? Int
        let filesCreated = statistics?["filesCreated"] as? Int
        let filesOpened = statistics?["filesOpened"] as? Int
        let filesDeleted = statistics?["filesDeleted"] as? Int
        let foldersCreated = statistics?["foldersCreated"] as? Int
        let foldersDeleted = statistics?["foldersDeleted"] as? Int

        if installVersion == nil {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]

            if version == nil {
                self.installVersion = "Unknown"
            } else {
                self.installVersion = String(describing: version!)
            }
        } else {
            self.installVersion = installVersion!
        }

        self.installDate = installDate == nil ? Date() : Date(timeIntervalSinceReferenceDate: installDate!)
        self.symbolsWrittenTotal = symbolsWrittenTotal ?? 0
        self.filesCreated = filesCreated ?? 0
        self.filesOpened = filesOpened ?? 0
        self.filesDeleted = filesDeleted ?? 0
        self.foldersCreated = foldersCreated ?? 0
        self.foldersDeleted = foldersDeleted ?? 0
    }

    func save() {
        let statistics = NSMutableDictionary()

        statistics["installVersion"] = installVersion
        statistics["installDate"] = installDate.timeIntervalSinceReferenceDate
        statistics["symbolsWrittenTotal"] = symbolsWrittenTotal
        statistics["filesCreated"] = filesCreated
        statistics["filesOpened"] = filesOpened
        statistics["filesDeleted"] = filesDeleted
        statistics["foldersCreated"] = foldersCreated
        statistics["foldersDeleted"] = foldersDeleted

        Defaults.set(statistics, forKey: DKey.statistics)
    }
}

internal class UserPreferences {

    var codeAutocompletionEnabled = true
    var consoleShouldVanishCode = true
    var adjustKeyboardAppearance = false
    var statistics = UserStatistics()
    var lineEndingSymbol: LineEndingSymbol = .lf
    var editorEncoding: String.Encoding = .utf8
    var emmetEnabled = true
    var language = Language.base
    var hapticFeedbackEnabled = true
    var bundle = Bundle.main
    var searchIsCaseSensitive = true
    var currentTheme = Theme.blueTheme
    var fontSize: Float = 12.0
    var enabledPlugins = [String]()
    var sortingType = SortingType.byType
    var syntaxHighlightingConfiguration = [SyntaxHighlightScheme]()
    var syntaxHighlightingEnabled = true
    var expanderButtonsList: [ExpanderButtonItem] = []

    internal func applyTheme(window: UIWindow? = nil) {

        let themedNavigationBarAppearance = ThemedNavigationBar.appearance()
        let themedToolBarAppearance = ThemedToolbar.appearance()

        if #available(iOS 13.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.titleTextAttributes = [.foregroundColor: userPreferences.currentTheme.navigationTitle]
            navBarAppearance.largeTitleTextAttributes = [.foregroundColor: userPreferences.currentTheme.navigationTitle]
            navBarAppearance.backgroundColor = currentTheme.themeColor

            let toolbarAppearance = UIToolbarAppearance()
            toolbarAppearance.configureWithOpaqueBackground()
            toolbarAppearance.backgroundColor = currentTheme.tabBarBackgroundColor

            themedNavigationBarAppearance.standardAppearance = navBarAppearance
            themedNavigationBarAppearance.scrollEdgeAppearance = navBarAppearance
            if #available(iOS 15.0, *) {
                themedNavigationBarAppearance.compactScrollEdgeAppearance = navBarAppearance
            }

            themedToolBarAppearance.standardAppearance = toolbarAppearance

            if #available(iOS 15.0, *) {
                themedToolBarAppearance.scrollEdgeAppearance = toolbarAppearance
                themedToolBarAppearance.compactScrollEdgeAppearance = toolbarAppearance
            }
        }

        themedNavigationBarAppearance.barTintColor = currentTheme.themeColor
        themedNavigationBarAppearance.tintColor = currentTheme.buttonColor
        themedNavigationBarAppearance.titleTextAttributes = [.foregroundColor: userPreferences.currentTheme.navigationTitle]
        themedNavigationBarAppearance.isTranslucent = true
        themedNavigationBarAppearance.barStyle = .blackTranslucent

        themedToolBarAppearance.barTintColor = currentTheme.themeColor
        themedToolBarAppearance.tintColor = currentTheme.buttonColor
        themedToolBarAppearance.isTranslucent = true
        themedToolBarAppearance.barStyle = .black

        UIApplication.shared.statusBarStyle = .lightContent

        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [.foregroundColor: UIColor.white]
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).attributedPlaceholder = NSAttributedString(string: localize("search", .editor), attributes: [.foregroundColor: UIColor(white: 1.0, alpha: 0.5)])
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = userPreferences.currentTheme.navigationTitle
        UIImageView.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = userPreferences.currentTheme.navigationTitle.withAlphaComponent(0.5)
        UISearchBar.appearance().setImage(UIImage(named: "searchbaricon")?.withRenderingMode(.alwaysTemplate), for: .search, state: .normal)
        UISearchBar.appearance().setImage(UIImage(), for: .clear, state: .normal)
    }

    static var plugins = [
        "autoCloseBrackets": ["m.closebrackets", "true"],
        "lineNumbers": ["", "true"],
        "matchTags": ["m.matchtags", "m.fold", "{bothTags:true}"],
        "matchBrackets": ["m.matchbrackets", "true"],
        "autoCloseTags": ["m.closetag", "m.fold", "true"],
        "foldGutter": ["m.folding", "m.fold", "true"],
        "colorpicker": ["m.colorpicker", "true"],
        "lineWrapping": ["", "true"]
    ]

    static let defaultPluginEnabled = [
        true, true, true, true, true, true, true, false, false
    ]

    internal func reload() {
        codeAutocompletionEnabled = Defaults.bool(forKey: DKey.codeAutocompletionEnabled, def: true)
        fontSize = Defaults.float(forKey: DKey.fontSize, def: 12)
        sortingType = SortingType(rawValue: Defaults.int(forKey: DKey.sortingType, def: 0)) ?? .none
        searchIsCaseSensitive = Defaults.bool(forKey: DKey.searchIsCaseSensitive, def: true)
        hapticFeedbackEnabled = Defaults.bool(forKey: DKey.hapticFeedbackEnabled, def: true)
        editorEncoding = String.Encoding(rawValue: Defaults.object(forKey: DKey.textEncoding, def: String.Encoding.utf8.rawValue) as! UInt)
        lineEndingSymbol = LineEndingSymbol(rawValue: Defaults.int8(forKey: DKey.lineEndingSymbol, def: LineEndingSymbol.lf.rawValue)) ?? .lf
        syntaxHighlightingEnabled = Defaults.bool(forKey: DKey.syntaxHighlightingEnabled, def: true)
        consoleShouldVanishCode = Defaults.bool(forKey: DKey.consoleShouldVanishCode, def: true)
        adjustKeyboardAppearance = Defaults.bool(forKey: DKey.adjustKeyboardAppearance, def: false)

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let versionString = Defaults.string(forKey: DKey.lastInstalledVersion, def: currentVersion)
        let lastInstalledVersion = Version(parsing: versionString) ?? Version(majorVersion: 1)

        Defaults.set(currentVersion, forKey: DKey.lastInstalledVersion)

        let priorTo132 = lastInstalledVersion.isPriorTo(1, 3, 2)
        let priorTo143 = lastInstalledVersion.isPriorTo(1, 4, 3)

        if let configuration = Defaults.object(forKey: DKey.syntaxHighlightingConfiguration) as? [SyntaxHighlightScheme.SerializedType] {

            syntaxHighlightingConfiguration = []
            syntaxHighlightingConfiguration.reserveCapacity(configuration.count)

            for item in configuration {
                if var type = SyntaxHighlightScheme.deserialize(type: item) {

                    if priorTo132 { // 1.3.2 conversion + 1.3.1 Bugfix
                        if type.mode.cmMimeType == "application/x-httpd-php" {
                            type.mode = .php
                        } else if type.mode.cmMimeType == "text/xml" {
                            type.mode = .xml
                        } else if type.mode.cmMimeType == "text/x-paskal" {
                            type.mode.cmMimeType = "text/x-pascal"
                        }
                    }

                    if priorTo143 {
                        for (i, mode) in type.mode.configurationFiles.enumerated() {
                            if mode.starts(with: "c.") {
                                type.mode.configurationFiles[i] = String(mode.suffix(mode.count - 2))
                            }
                        }
                    }

                    syntaxHighlightingConfiguration.append(type)
                }
            }

            if (priorTo143) {
                UserDefaults.standard.removeObject(forKey: "notifyWhenNight")
                // Update syntax configuration
                var serialized = [SyntaxHighlightScheme.SerializedType]()

                for scheme in syntaxHighlightingConfiguration {
                    serialized.append(scheme.serialize())
                }

                Defaults.set(serialized, forKey: DKey.syntaxHighlightingConfiguration)
            }

            if lastInstalledVersion.isPriorTo(1, 4, 6) {
                syntaxHighlightingConfiguration.append(contentsOf: [
                    .init(ext: "mysql", mode: .mysql),
                    .init(ext: "sql", mode: .mysql),
                    .init(ext: "db", mode: .mysql),
                    .init(ext: "hql", mode: .hive)
                ])
            }

        } else {

            syntaxHighlightingConfiguration = [
                .init(ext: "htm", mode: .html),
                .init(ext: "html", mode: .html),
                .init(ext: "js", mode: .javascript),
                .init(ext: "css", mode: .css),
                .init(ext: "scss", mode: .scss),
                .init(ext: "xml", mode: .xml),
                .init(ext: "plist", mode: .xml),
                .init(ext: "java", mode: .java),
                .init(ext: "m", mode: .objectivec),
                .init(ext: "scala", mode: .scala),
                .init(ext: "c", mode: .c),
                .init(ext: "h", mode: .c),
                .init(ext: "cpp", mode: .cpp),
                .init(ext: "hpp", mode: .cpp),
                .init(ext: "cs", mode: .csharp),
                .init(ext: "swift", mode: .swift),
                .init(ext: "py", mode: .python),
                .init(ext: "pas", mode: .pascal),
                .init(ext: "lua", mode: .lua),
                .init(ext: "md", mode: .markdown),
                .init(ext: "php", mode: .php),
                .init(ext: "json", mode: .json),
                .init(ext: "svg", mode: .xml),
                .init(ext: "f", mode: .fortran),
                .init(ext: "f77", mode: .fortran),
                .init(ext: "for", mode: .fortran),
                .init(ext: "ftn", mode: .fortran),
                .init(ext: "fs", mode: .fsharp),
                .init(ext: "fsx", mode: .fsharp),
                .init(ext: "ocaml", mode: .ocaml),
                .init(ext: "txt", mode: .txt),
                .init(ext: "mysql", mode: .mysql),
                .init(ext: "sql", mode: .mysql),
                .init(ext: "db", mode: .mysql),
                .init(ext: "hql", mode: .hive),
            ]
        }

        if priorTo132 {
            // 1.4 switches the primary color scheme to blue

            Defaults.set(3, forKey: DKey.theme)

            currentTheme = Theme.blueTheme
        } else {
            currentTheme = Theme.themes[Defaults.int(forKey: DKey.theme, def: 3)]
        }
        
        if let preferredLocale = Defaults.object(forKey: DKey.language) as? String {
            let preferredLanguage = applicationLanguages.first(where: { $0.code == preferredLocale })
            language = preferredLanguage ?? language
        } else {
            let deviceLanguageCode = NSLocale.current.languageCode ?? "en"
            let preferredLanguage = applicationLanguages.first(where: { $0.languageCodes.contains(deviceLanguageCode) })
            language = preferredLanguage ?? language
        }

        let path = Bundle.main.path(forResource: userPreferences.language.code, ofType: "lproj")
        bundle = Bundle(path: path!)!

        for (i, arg) in UserPreferences.plugins.enumerated() {

            let plugin = arg.key
            let pluginKey = "pl.\(plugin)"

            var isEnabled = Defaults.object(forKey: pluginKey) as? Bool

            if isEnabled == nil {

                let defaultValue = UserPreferences.defaultPluginEnabled[i]

                Defaults.set(defaultValue, forKey: pluginKey)
                isEnabled = defaultValue
            }

            if isEnabled! == true {
                userPreferences.enabledPlugins.append(plugin)
            }
        }

        var expanderConfig = Defaults.object(forKey: DKey.expanderConfig) as? [Int]

        if expanderConfig == nil {
            expanderConfig = [
                ExpanderButtonItem.ButtonType.undo.rawValue,
                ExpanderButtonItem.ButtonType.redo.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.search.rawValue,
                ExpanderButtonItem.ButtonType.replace.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.colorpicker.rawValue,
                ExpanderButtonItem.ButtonType.gradientpicker.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.save.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.fontup.rawValue,
                ExpanderButtonItem.ButtonType.fontdown.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.bracketleft.rawValue,
                ExpanderButtonItem.ButtonType.bracketright.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.curvedbracketleft.rawValue,
                ExpanderButtonItem.ButtonType.curvedbracketright.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.squarebracketleft.rawValue,
                ExpanderButtonItem.ButtonType.squarebracketright.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.lessthan.rawValue,
                ExpanderButtonItem.ButtonType.greaterthan.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.quote.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.goSymbolLeft.rawValue,
                ExpanderButtonItem.ButtonType.goSymbolRight.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.tab.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.commentLine.rawValue,
                -1,
                ExpanderButtonItem.ButtonType.indent.rawValue
            ]

            Defaults.defaults.set(expanderConfig, forKey: DKey.expanderConfig)
        }

        expanderButtonsList.reserveCapacity(expanderConfig!.count)

        for raw in expanderConfig! {
            if raw == -1 {
                expanderButtonsList.append(.delimiter)
            } else {
                expanderButtonsList.append(.button(.init(type: ExpanderButtonItem.ButtonType(rawValue: raw)!)))
            }
        }
    }
}

let userPreferences = UserPreferences()
