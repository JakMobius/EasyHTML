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
    
    /**
     Отображает `UIProgressView` с указанным прогрессом, если его значение больше нуля. Иначе, скрывает `UIProgressView`
     */
    
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
    
    /**
     Функция-сигнал о нажатии на кнопку "Отмена" в окне активности. Не вызывается при нажатии на кнопку "Отмена" в окне ошибки запроса.
     */
    
    internal var cancelHandler: (() -> ())? = nil
    
    internal func operationFailed(with error: Any?, retryHandler: @escaping () -> ()) {
        
        progressView?.isHidden = true
        
        let description: String
        
        if let error = error as? NSError {
            // Нам подсунули FTP / SFTP запрос
            
            description = error.localizedDescription
        } else if let error = error as? GeneralizedCallError {
            
            // Имеем дело с Dropbox API
            
            description = DropboxError(error: error)?.localizedDescription ?? localize("unknownerror")
        } else if let error = error as? String {
            // Имеем дело с FTP / SFTP
            
            description = error
        } else {
            // Шо это??
            
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
