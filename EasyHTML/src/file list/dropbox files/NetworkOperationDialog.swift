//
//  NetworkOperationDialog.swift
//  EasyHTML
//
//  Created by Артем on 02/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

internal class NetworkOperationDialog: NSObject {
    internal let alert: TCAlertController
    internal let textView: UITextView
    internal var activityIndicator: UIActivityIndicatorView! = nil
    internal var progressView: UIProgressView! = nil

    /// Displays `UIProgressView` with specified progress if its value is greater than zero. Otherwise, hides `UIProgressView`.
    internal func setProgress(_ progress: Float, animated: Bool = true) {
        if progress < 0 {
            progressView?.isHidden = true
            activityIndicator?.isHidden = true
        } else {
            if progressView == nil {
                progressView = alert.addProgressView()
            }

            progressView?.isHidden = false
            activityIndicator?.isHidden = true

            progressView.setProgress(progress, animated: animated)
        }
    }

    internal override init() {
        alert = TCAlertController.getNew()
        alert.contentViewHeight = 40
        alert.constructView()
        textView = alert.addTextView()
        activityIndicator = alert.addActivityIndicator()

        super.init()

        alert.applyDefaultTheme()
        alert.constructView()
        alert.minimumButtonsForVerticalLayout = 1
        textView.isHidden = true

        operationStarted()
    }

    internal func present(on view: UIView) {
        view.addSubview(alert.view)
    }

    internal func operationStarted() {

        alert.clearActions()

        alert.addAction(action: TCAlertAction(text: localize("cancel"), action: {
            _, _ in
            self.cancelHandler?()
        }, shouldCloseAlert: true))

        textView.isHidden = true
        activityIndicator.startAnimating()
    }

    internal func operationCompleted() {
        alert.dismissWithAnimation()
    }

    /// The callback of the "Cancel" button in the activity window. Not triggered by the "Cancel" button in the
    /// error window.
    internal var cancelHandler: (() -> ())? = nil

    internal func operationFailed(with error: Any?, retryHandler: @escaping () -> ()) {

        progressView?.isHidden = true

        let description: String

        if let error = error as? NSError {
            // May happen on FTP / SFTP error
            description = error.localizedDescription
        } else if let error = error as? GeneralizedCallError {
            // Dropbox API error
            description = DropboxError(error: error)?.localizedDescription ?? localize("unknownerror")
        } else if let error = error as? String {
            // May also happen on FTP / SFTP error
            description = error
        } else {
            description = localize("unknownerror")
        }

        textView.isHidden = false
        activityIndicator.stopAnimating()

        textView.text = description
        let header = alert.header.text
        alert.header.text = localize("error")

        alert.clearActions()
        alert.addAction(action: TCAlertAction(text: localize("tryagain"), action: { _, _ in
            self.alert.header.text = header
            retryHandler()
        }))
        alert.addAction(action: TCAlertAction(text: localize("cancel"), shouldCloseAlert: true))
    }
}
