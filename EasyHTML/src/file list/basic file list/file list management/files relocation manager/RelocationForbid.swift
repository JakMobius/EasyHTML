//
//  RelocationForbid.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

extension FilesRelocationManager {
    enum RelocationForbiddenReason {
        case unsupportedController, unsupportedFile, loadingIsInProcess, custom(description: String)

        var localizedDescription: String {
            switch self {
            case .unsupportedController:
                return localize("cannotmovefileshere", .files)
            case .unsupportedFile:
                return localize("cannotmovethisfilehere", .files)
            case .loadingIsInProcess:
                return localize("cannotmoveloadingisinprogress", .files)
            case .custom(let description):
                return description
            }
        }
    }

    final func showMovingForbiddenSign(reason: RelocationForbiddenReason) {

        hintTimer?.invalidate()

        if currentSign != nil {
            currentSign.label.setTextWithFadeAnimation(text: reason.localizedDescription, duration: 0.5, completion: nil)
        } else {
            createSign(text: reason.localizedDescription)
        }

        currentSign.tag = -1
    }

    final func hideMovingForbiddenSign() {
        guard let sign = currentSign else {
            return
        }
        guard currentSign!.tag == -1 else {
            return
        }

        currentSign = nil

        UIView.animate(withDuration: 0.5, animations: {
            sign.alpha = 0.0
        }, completion: {
            _ in
            sign.removeFromSuperview()

            self.restoreGuideSigns()
        })
    }
}
