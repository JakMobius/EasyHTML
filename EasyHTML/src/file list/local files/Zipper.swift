//
//  Zipper.swift
//  EasyHTML
//
//  Created by Артем on 31.05.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit
import Zip

internal struct Zipper {
    
    private static func createAlertController() -> TCAlertController {
        let alert = TCAlertController.getNew()
        
        alert.applyDefaultTheme()
        alert.closeAnimation = TCAnimation(animations: [.opacity, .scale(0.5, 0.5)], duration: 0.3)
        
        alert.contentViewHeight = 40
        alert.constructView()
        
        alert.animation = TCAnimation(animations: [.opacity], duration: 0.3, delay: 0.0)
        alert.addAction(action: TCAlertAction(text: "OK", shouldCloseAlert: true))
        alert.buttons[0].isEnabled = false
        
        return alert
    }
    
    internal static func zipFile(on view: UIView!, at url: URL, to destinationURL: URL, compression: ZipCompression, password: String, completion: (() -> ())? = nil) {
        let alert = createAlertController()
        view?.addSubview(alert.view)
        let progressView = alert.addProgressView()
        
        alert.headerText = localize("archivingtitle")
        
        let paths: [URL]
        
        if isDir(fileName: url.path) {
            do {
                paths = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            } catch {
                completion?()
                return
            }
        } else {
            paths = [url]
        }
        
        // Клятi Minizip.
        // Мне пришлось потратить несколько часов, чтобы понять, что
        // он вызывает метод progress с аргументом 1.0 несколько раз.
        // А так, как завершение процесса определяется как раз
        // путём сравнения аргумента с единицей, метод completion
        // вызывается несколько раз. Последствия могут быть разными.
        
        // Не убирай эту переменную.
        
        var finished = false
        
        DispatchQueue(label: "easyhtml.zipqueue").async {
            do {
                try Zip.zipFiles(paths: paths, zipFilePath: destinationURL, password: password.isEmpty ? nil : password, compression: compression, progress: { (progress) in
                    DispatchQueue.main.async {
                        if(progress == 1.0) {
                            if !finished {
                                alert.dismissWithAnimation()
                                completion?()
                                finished = true
                            }
                        } else {
                            progressView.setProgress(Float(progress), animated: true)
                        }
                    }
                })
                
            } catch {
                DispatchQueue.main.async {
                    progressView.removeFromSuperview()
                    alert.buttons[0].isEnabled = true
                    alert.headerText = localize("archivingerror")
                    
                    let label = UILabel(frame: CGRect(x: 10, y: 0, width: 230, height: 40))
                    label.text = localize("archivingerrordesc")
                    label.textColor = UIColor.gray
                    label.font = UIFont.systemFont(ofSize: 13)
                    label.numberOfLines = 3
                    label.textAlignment = .center
                    alert.contentView.addSubview(label)
                }
            }
        }
    }
    
    private static func shakeAlert(_ alert: TCAlertController) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.6
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0 ]
        alert.alertView.layer.add(animation, forKey: "shake")
    }
    
    private static func handleWrongPassword(alert: TCAlertController, progressView: UIProgressView, textField: UITextField) {
        if(UIDevice.current.produceSimpleHapticFeedback(level: 1102)) {
            if #available(iOS 10.0, *) {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.error)
            }
        }
        
        alert.headerText = localize("unarchivingwrongpassword")
        self.shakeAlert(alert)
        
        alert.buttons[0].isEnabled = true
        alert.buttons[1].isEnabled = true
        textField.isHidden = false
        progressView.isHidden = true
        
        DispatchQueue(label: "easyhtml.unzip.dialoganimationqueue").asyncAfter(deadline: .now() + 0.6) {
            DispatchQueue.main.async {
                textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
            }
        }
        
        return
    }
    
    private static func checkErrorTypeForWrongPassword(_ error: Error) -> Bool {
        if let zipError = error as? ZipError, case .unzipFail(let code) = zipError {
            
            if(code != ZipErrorCode.BadZipFile.errorCode) {
                return true
            }
        }
        return false
    }
    
    private static func presentCorruptedArchiveWarning(alert: TCAlertController, progressView: UIProgressView) {
        alert.clearActions()
        alert.addAction(action: TCAlertAction(text: "OK", shouldCloseAlert: true))
        
        progressView.removeFromSuperview()
        alert.headerText = localize("unarchivingerror")
        let label = UILabel(frame: CGRect(x: 10, y: 0, width: 230, height: 40))
        label.text = localize("unarchivingerrordesc")
        label.textColor = UIColor.gray
        label.font = UIFont.systemFont(ofSize: 13)
        label.numberOfLines = 3
        label.textAlignment = .center
        alert.contentView.addSubview(label)
    }
    
    internal static func unzipFile(on view: UIView!, at url: URL, to destinationURL: URL, completion: (() -> ())? = nil) {
        
        let alert = createAlertController()
        view?.addSubview(alert.view)
        let progressView = alert.addProgressView()
        
        alert.headerText = localize("unarchivingtitle")
        
        DispatchQueue(label: "easyhtml.unzipqueue").async {
            
            // Клятi Minizip.
            
            // Мне пришлось потратить несколько часов, чтобы понять, что
            // он вызывает метод progress с аргументом 1.0 несколько раз.
            // А так, как завершение процесса определяется как раз
            // путём сравнения аргумента с единицей, метод completion
            // вызывается несколько раз. Последствия могут быть разными.
            
            // Не убирай эту переменную.
            
            var finished = false
            
            func handleProgress(progress: Double) {
                DispatchQueue.main.async {
                    if(progress == 1.0) {
                        if !finished {
                            alert.dismissWithAnimation()
                            completion?()
                            finished = true
                        }
                    } else {
                        progressView.setProgress(Float(progress), animated: true)
                    }
                }
            }
            do {
                try Zip.unzipFile(url, destination: destinationURL, overwrite: false, password: nil, progress: handleProgress)
            } catch {
                try? FileManager.default.removeItem(at: destinationURL)
                
                DispatchQueue.main.async {
                    
                    if self.checkErrorTypeForWrongPassword(error) {
                        let textField = UITextField(frame: CGRect(x: 10, y: 5, width: 230, height: 30))
                        
                        func tryPassword(button: UIButton, alert: TCAlertController) {
                            textField.selectedTextRange = nil
                            
                            alert.buttons[0].isEnabled = false
                            alert.buttons[1].isEnabled = false
                            textField.isHidden = true
                            progressView.isHidden = false
                            let password = textField.text!
                            DispatchQueue(label: "easyhtml.unzipqueue").async {
                                
                                do {
                                    try Zip.unzipFile(url, destination: destinationURL, overwrite: false, password: password, progress: handleProgress)
                                } catch {
                                    try? FileManager.default.removeItem(at: destinationURL)
                                    
                                    DispatchQueue.main.async {
                                        if self.checkErrorTypeForWrongPassword(error) {
                                            self.handleWrongPassword(alert: alert, progressView: progressView, textField: textField)
                                            return
                                        }
                                        textField.removeFromSuperview()
                                        textField.delegate = alert
                                        self.presentCorruptedArchiveWarning(alert: alert, progressView: progressView)
                                    }
                                }
                            }
                        }
                        
                        alert.clearActions()
                        alert.headerText = localize("unarchivingenterpassword")
                        
                        textField.layer.borderColor = userPreferences.currentTheme.themeColor.cgColor
                        textField.layer.borderWidth = 1.0
                        textField.layer.masksToBounds = true
                        textField.layer.cornerRadius = 3.0
                        textField.setLeftPaddingPoints(6.0)
                        textField.isSecureTextEntry = true
                        textField.placeholder = localize("password")
                        textField.returnKeyType = .done
                        alert.contentView.addSubview(textField)
                        
                        progressView.isHidden = true
                        alert.addAction(action: TCAlertAction(text: "OK", action: tryPassword))
                        alert.addAction(action: TCAlertAction(text: localize("cancel"), shouldCloseAlert: true))
                        return
                    }
                    self.presentCorruptedArchiveWarning(alert: alert, progressView: progressView)
                }
            }
        }
    }
}
