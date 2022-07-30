//
//  FileListNavigationController.swift
//  EasyHTML
//
//  Created by Артем on 15.04.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class FileListNavigationController: TabNavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        toolbar.isTranslucent = false
        isToolbarHidden = false
        shouldHideBackButton = false
    }

    override func updateTheme() {
        super.updateTheme()

        updateToolbarStyle()
    }

    private func updateToolbarStyle() {
        toolbar.barStyle = userPreferences.currentTheme.isDark ? .black : .default
        toolbar.setBackgroundImage(UIImage.getImageFilledWithColor(color: userPreferences.currentTheme.tabBarBackgroundColor), forToolbarPosition: .any, barMetrics: .default)
    }

    var folderPicker: FolderPickerViewController!

    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        guard folderPicker == nil else {
            return
        }
        guard viewControllers.isEmpty else {
            return
        }

        folderPicker = FolderPickerViewController.instance(for: view)

        viewControllers = [folderPicker]
        _ = folderPicker.view

        folderPicker.setup(parent: self)
        updateToolbarStyle()
    }
}
