//
//  Theme.swift
//  EasyHTML
//
//  Created by Артем on 11.10.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import Foundation
import UIKit

class Theme {
    let themeColor: UIColor
    let buttonColor: UIColor
    let buttonDarkColor: UIColor
    let navigationTitle: UIColor
    let background: UIColor
    let cellColor1: UIColor
    let cellColor2: UIColor
    let cellTextColor: UIColor
    let cellSelectedColor: UIColor
    let detailDisclosureButtonColor: UIColor
    let isDark: Bool
    let statusBarStyle: UIStatusBarStyle
    let tableViewDelimiterColor: UIColor
    let secondaryTextColor: UIColor
    let tabBarBackgroundColor: UIColor
    let tabBarSelectedItemColor: UIColor
    let id: Int
    
    init(themeColor: UIColor, buttonColor: UIColor, buttonDarkColor: UIColor, navigationTitle: UIColor, cellColor1: UIColor, cellColor2: UIColor, cellTextColor: UIColor, cellSelectedColor: UIColor, tableViewDelimiterColor: UIColor, secondaryTextColor: UIColor, detailDisclosureButtonColor: UIColor, background: UIColor, tabBarBackgroundColor: UIColor, tabBarSelectedItemColor: UIColor, id: Int, statusBarStyle: UIStatusBarStyle = .default, isDark: Bool = false)
    {
        self.themeColor = themeColor
        self.buttonColor = buttonColor
        self.buttonDarkColor = buttonDarkColor
        self.navigationTitle = navigationTitle
        self.isDark = isDark
        self.cellColor1 = cellColor1
        self.cellColor2 = cellColor2
        self.cellTextColor = cellTextColor
        self.cellSelectedColor = cellSelectedColor
        self.background = background
        self.statusBarStyle = statusBarStyle
        self.detailDisclosureButtonColor = detailDisclosureButtonColor
        self.tableViewDelimiterColor = tableViewDelimiterColor
        self.secondaryTextColor = secondaryTextColor
        self.tabBarBackgroundColor = tabBarBackgroundColor
        self.tabBarSelectedItemColor = tabBarSelectedItemColor
        self.id = id
    }
    
    static let greenTheme = Theme(
        themeColor: UIColor(red: 0.17, green: 0.75, blue: 0.39, alpha: 1.0),
        buttonColor: UIColor.white,
        buttonDarkColor: UIColor(red: 0.17, green: 0.75, blue: 0.39, alpha: 1.0),
        navigationTitle: UIColor.white,
        cellColor1: UIColor(red: 0.985, green: 0.985, blue: 0.985, alpha: 1.0),
        cellColor2: UIColor.white,
        cellTextColor: UIColor.black,
        cellSelectedColor: UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0),
        tableViewDelimiterColor: UIColor.lightGray,
        secondaryTextColor: UIColor.darkGray,
        detailDisclosureButtonColor: UIColor(red: 0.17, green: 0.75, blue: 0.39, alpha: 1.0),
        background: UIColor.white,
        tabBarBackgroundColor: UIColor.white,
        tabBarSelectedItemColor: UIColor(red: 0.0, green: 0.478, blue:1.0, alpha:1.0),
        id: 0,
        statusBarStyle: .lightContent
    )
    
    static let redTheme = Theme (
        themeColor: #colorLiteral(red: 0.5, green: 0, blue: 0, alpha: 1),
        buttonColor: UIColor.white,
        buttonDarkColor: #colorLiteral(red: 0.5, green: 0, blue: 0, alpha: 1),
        navigationTitle: UIColor.white,
        cellColor1: UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
        cellColor2: UIColor.white,
        cellTextColor: UIColor.black,
        cellSelectedColor: UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0),
        tableViewDelimiterColor: UIColor.lightGray,
        secondaryTextColor: UIColor.darkGray,
        detailDisclosureButtonColor: #colorLiteral(red: 0.7037165179, green: 0, blue: 0, alpha: 1),
        background: UIColor.white,
        tabBarBackgroundColor: UIColor.white,
        tabBarSelectedItemColor: UIColor(red: 0.0, green: 0.478, blue:1.0, alpha:1.0),
        id: 1,
        statusBarStyle: .lightContent
    )
    
    static let darkTheme = Theme (
        themeColor: UIColor.black,
        buttonColor: UIColor.white,
        buttonDarkColor: UIColor.lightGray,
        navigationTitle: UIColor.white,
        cellColor1: UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0),
        cellColor2: UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0),
        cellTextColor: UIColor.white,
        cellSelectedColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
        tableViewDelimiterColor: UIColor.darkGray,
        secondaryTextColor: UIColor.lightGray,
        detailDisclosureButtonColor: UIColor.white,
        background: UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0),
        tabBarBackgroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0),
        tabBarSelectedItemColor: UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),
        id: 2,
        statusBarStyle: .lightContent,
        isDark: true
    )
    
    static let blueTheme = Theme (
        themeColor: #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1),
        buttonColor: UIColor.white,
        buttonDarkColor: #colorLiteral(red: 0.2344586175, green: 0.33247655, blue: 0.400000006, alpha: 1),
        navigationTitle: UIColor.white,
        cellColor1: UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
        cellColor2: UIColor.white,
        cellTextColor: UIColor.black,
        cellSelectedColor: UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0),
        tableViewDelimiterColor: UIColor.lightGray,
        secondaryTextColor: UIColor.darkGray,
        detailDisclosureButtonColor: #colorLiteral(red: 0.1081405717, green: 0.3033943725, blue: 0.4325622867, alpha: 1),
        background: UIColor.white,
        tabBarBackgroundColor: UIColor.white,
        tabBarSelectedItemColor: UIColor(red: 0.0, green: 0.478, blue:1.0, alpha:1.0),
        id: 3,
        statusBarStyle: .lightContent
    )
    
    internal static var themes = [Theme.greenTheme, Theme.redTheme, Theme.darkTheme, Theme.blueTheme]
}
