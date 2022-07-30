//
//  UnknownExtensionAlert.swift
//  EasyHTML
//
//  Created by Артем on 09/01/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

enum EditorType {
    case sourceCodeEditor
    case webBrowser
}

class UnknownExtensionAlert {

    static func present(on view: UIView, file: FSNode, callback: @escaping (EditorType) -> ()) {


        let ext = file.url.pathExtension

        let alert = TCAlertController.getNew()
        alert.applyDefaultTheme()
        alert.contentViewHeight = 50.0
        alert.minimumButtonsForVerticalLayout = 0
        alert.constructView()

        alert.addTextView().text = localize("ue_desc", .editor).replacingOccurrences(of: "#0", with: ext)

        let header = localize("unknownextension")

        alert.headerText = header
        alert.makeCloseableByTapOutside()

        alert.addAction(action: TCAlertAction(text: localize("showsource"), action: {
            _, _ in
            callback(.sourceCodeEditor)
        }, shouldCloseAlert: true))
        alert.addAction(action: TCAlertAction(text: localize("showcontent"), action: {
            _, _ in
            callback(.webBrowser)
        }, shouldCloseAlert: true))

        alert.animation = TCAnimation(animations: [TCAnimationType.scale(0.8, 0.8)], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.5)

        view.addSubview(alert.view)
    }
}
