//
//  FileCreationDialog.swift
//  EasyHTML
//
//  Created by Артем on 27.04.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

/**
    Результат создания файла / папки
 */

internal enum FileCreationResult {
    case success, wrongName, filenameUsed, other
    
    var description: String {
        switch self {
        case .success: return "OK"
        case .wrongName: return localize("wrongfilename")
        case .filenameUsed: return localize("filenameisalreadyused")
        case .other: return localize("unknownerror")
        }
    }
}

internal protocol FileCreationDialogDelegate: class {
    
    /**
        Метод, вызывающийся при нажатии на кнопку "Создать файл".
     
    - parameter controller: Контроллер, который вызвал данный метод
    - parameter named: Название файла
    - parameter callback: Сигнал завершения проверки. Аргументом является результат проверки названия на валидность и создания файла. При удачном создании файла контроллер самостоятельно скроется, иначе - покажет ошибку.
    */
    
    func fileCreationDialog(controller: FileCreationDialog, createFile named: String, completion: @escaping (FileCreationResult) -> ())
    
    /**
     Метод, вызывающийся при нажатии на кнопку "Создать папку".
     
     - parameter controller: Контроллер, который вызвал данный метод
     - parameter named: Название папки
     - parameter callback: Сигнал завершения проверки. Аргументом является результат проверки названия на валидность и создания папки. При удачном создании папки контроллер самостоятельно скроется, иначе - покажет ошибку.
     */
    
    func fileCreationDialog(controller: FileCreationDialog, createFolder named: String, completion: @escaping (FileCreationResult) -> ())
}

internal class FileCreationDialog: NSObject {
    
    internal let alert: TCAlertController
    internal let textField: UITextField
    internal weak var fileCreationDelegate: FileCreationDialogDelegate?
    internal let isFolder: Bool
    private var activityIndicator: UIActivityIndicatorView! = nil
    private let defaultFileName: String
    
    internal init(isFolder: Bool, defaultFileName: String) {

        alert = TCAlertController.getNew()
        alert.applyDefaultTheme()
        alert.contentViewHeight = 30.0
        alert.constructView()
        textField = alert.addTextField()
        self.isFolder = isFolder
        self.defaultFileName = defaultFileName
        
        super.init()
        
        textField.returnKeyType = .done
        textField.placeholder = localize(/*# -tcanalyzerignore #*/ isFolder ? "foldername" : "filename")
        textField.text = defaultFileName
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        
        if #available(iOS 11.0, *) {
            textField.smartQuotesType = .no
            textField.smartInsertDeleteType = .no
            textField.spellCheckingType = .no
        }
        
        let header = localize(/*# -tcanalyzerignore #*/ isFolder ? "newfolder" : "newfile")
        
        alert.headerText = header
        alert.makeCloseableByTapOutside()
        
        alert.addAction(action: TCAlertAction(text: localize(/*# -tcanalyzerignore #*/ isFolder ? "createfolder" : "createfile"), action: {
            _, _ in
            self.textField.selectedTextRange = nil
            self.create()
        }))
        alert.addAction(action: TCAlertAction(text: localize("cancel"), shouldCloseAlert: true))
        
        activityIndicator = alert.addActivityIndicator(offset: CGPoint(x: 0, y: -6 ))
        alert.contentView.addSubview(textField)
        
        alert.animation = TCAnimation(animations: [TCAnimationType.scale(0.8, 0.8)], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.5)
        
        /// Длина расширения файла. Используется при расчете диапозона выделения названия файла
        var offset = getFileExtensionFromString(fileName: defaultFileName).count
        if(offset > 0) {
            offset += 1
        }
        
        textField.becomeFirstResponder()
        
        DispatchQueue.main.async {
            self.textField.selectedTextRange = self.textField.textRange(
                from: self.textField.beginningOfDocument,
                to: self.textField.position (
                    from: self.textField.endOfDocument,
                    offset: -offset
                )!
            )
        }
    }
    
    private var task: DispatchWorkItem? = nil
    
    private func create() {
        var name = textField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        textField.isHidden = true
        activityIndicator.startAnimating()
        
        var result: FileCreationResult
        
        if name.contains("/") || name.count == 0 {
            result = .wrongName
        } else {
            result = .success
        }
        
        func callback(result: FileCreationResult) {
            if result == .success {
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
                    self.alert.header.setTextWithFadeAnimation(text: localize(/*# -tcanalyzerignore #*/ self.isFolder ? "newfolder" : "newfile"))
                }
                DispatchQueue.main.asyncAfter(deadline: when, execute: task!)
                
                return;
            }
        }
        
        if result == .success {
            
            alert.buttons[0].isEnabled = false
            alert.buttons[1].isEnabled = false
            
            if isFolder {
                fileCreationDelegate?.fileCreationDialog(controller: self, createFolder: name, completion: callback)
            } else {
                fileCreationDelegate?.fileCreationDialog(controller: self, createFile: name, completion: callback)
            }
        } else {
            callback(result: result)
        }
    }
}
