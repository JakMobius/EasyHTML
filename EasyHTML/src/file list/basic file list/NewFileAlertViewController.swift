//
//  NewFileAlertView.swift
//  EasyHTML
//
//  Created by Артем on 27.04.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

protocol NewFileDialogDelegate: AnyObject {
    func newFileDialog(dialog: NewFileDialog, hasPicked image: UIImage)
}

class NewFileDialog: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    internal struct Config {
        internal var canCreateFiles: Bool
        internal var canCreateFolders: Bool
        internal var canImportPhotos: Bool
        internal var canImportLibraries: Bool

        internal var canImportMedia: Bool {
            canImportPhotos || canImportLibraries
        }
    }

    internal let config: Config

    internal var window: UIWindow!

    internal let alert: TCAlertController
    internal weak var libraryPickerDelegate: LibraryPickerDelegate? = nil
    internal weak var fileCreationDelegate: FileCreationDialogDelegate? = nil
    internal weak var delegate: NewFileDialogDelegate? = nil

    @objc internal func createFolder() {

        alert.translateTo(animation: TCAnimation(animations: [TCAnimationType.opacity]), completion: {
            _ in
            self.alert.dismissAllAlertControllers()

            let dialog = FileCreationDialog(isFolder: true, defaultFileName: localize("newfolder"))
            dialog.fileCreationDelegate = self.fileCreationDelegate

            self.window.addSubview(dialog.alert.view)
        })
    }

    @objc internal func createFile() {
        alert.translateTo(animation: TCAnimation(animations: [.move(0, -400), .opacity], duration: 0.5))

        let alert1 = TCAlertController.getNew()
        alert1.minimumButtonsForVerticalLayout = 0

        func createFile(ext: String = "") {
            alert1.translateTo(animation: TCAnimation(animations: [.opacity]), completion: {
                _ in
                alert1.dismissAllAlertControllers()

                let dialog = FileCreationDialog(isFolder: false, defaultFileName: localize("newfile") + ext)
                dialog.fileCreationDelegate = self.fileCreationDelegate

                self.window.addSubview(dialog.alert.view)
            })
        }

        alert1.applyDefaultTheme()

        alert1.closeAnimation = TCAnimation(animations: [.opacity, .rotate(0.4), .scale(0.4, 0.4)], duration: 0.4)

        alert1.constructView()

        alert1.addAction(action: TCAlertAction(text: "HTML", action: {
            _, _ in
            createFile(ext: ".html")
        }))
        alert1.addAction(action: TCAlertAction(text: "CSS", action: {
            _, _ in
            createFile(ext: ".css")
        }))
        alert1.addAction(action: TCAlertAction(text: "JavaScript", action: {
            _, _ in
            createFile(ext: ".js")
        }))
        alert1.addAction(action: TCAlertAction(text: localize("otherfiletype"), action: {
            _, _ in
            createFile()
        }))

        alert1.addAction(action: TCAlertAction(text: localize("close"), shouldCloseAlert: true))

        alert1.makeCloseableByTapOutside()

        alert1.headerText = localize("createfile")
        alert1.animation = TCAnimation(animations: [.move(0, 400), .opacity], duration: 0.5)

        alert.present(alert1, animated: false)
    }

    @objc internal func importMedia() {
        alert.translateTo(animation: TCAnimation(animations: [.opacity, .move(-400, 0)], duration: 0.5))

        let alert1 = TCAlertController.getNew()
        alert1.minimumButtonsForVerticalLayout = 0
        alert1.applyDefaultTheme()

        alert1.closeAnimation = TCAnimation(animations: [.opacity, .scale(0.4, 0.4)], duration: 0.4)
        alert1.constructView()

        func importFromCameraRoll(button: UIButton, sender: TCAlertController) {
            imagePicked = false
            sender.translateTo(animation: TCAnimation(animations: [.opacity]), completion: {
                _ in
                sender.dismissAllAlertControllers()
                if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                    let imagePicker = UIImagePickerController()
                    imagePicker.delegate = self
                    imagePicker.sourceType = .photoLibrary
                    self.window.rootViewController!.present(imagePicker, animated: true)
                }
            })
        }

        alert1.addAction(action: TCAlertAction(text: localize("importphoto"), action: config.canImportMedia ? importFromCameraRoll : nil))


        func importLib(type: LibraryPickerViewController.LibraryType) {
            alert1.translateTo(animation: TCAnimation(animations: [.opacity]), completion: {
                _ in
                alert1.dismissAllAlertControllers()

                let libraryPicker = LibraryPickerViewController()
                libraryPicker.libraryType = type
                libraryPicker.libraryPickerDelegate = self.libraryPickerDelegate

                let navigationController = ThemeColoredNavigationController(rootViewController: libraryPicker)
                navigationController.modalPresentationStyle = .formSheet

                self.window.rootViewController!.present(navigationController, animated: true, completion: nil)
            })
        }

        alert1.addAction(action: TCAlertAction(text: localize("importjslib"), action: config.canImportLibraries ? {
            _, _ in
            importLib(type: .js)
        } : nil))
        alert1.addAction(action: TCAlertAction(text: localize("importcsslib"), action: config.canImportLibraries ? {
            _, _ in
            importLib(type: .css)
        } : nil))

        alert1.addAction(action: TCAlertAction(text: localize("close"), shouldCloseAlert: true))

        alert1.makeCloseableByTapOutside()

        alert1.headerText = localize("import")
        alert1.animation = TCAnimation(animations: [.move(400, 0), .opacity], duration: 0.5)

        alert.present(alert1, animated: false)
    }

    internal init(config: Config) {
        self.config = config
        alert = TCAlertController.getNew()
        super.init()

        alert.minimumButtonsForVerticalLayout = 0
        alert.applyDefaultTheme()
        alert.constructView()
        alert.makeCloseableByTapOutside()
        alert.headerText = localize("create")

        alert.animation = TCAnimation(animations: [.move(-100, -200), .rotate(0.4), .scale(0.4, 1.6)], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.5)

        alert.addAction(action: TCAlertAction(text: localize("folder"), action: config.canCreateFolders ? {
            _, _ in
            self.createFolder()
        } : nil))
        alert.addAction(action: TCAlertAction(text: localize("file"), action: config.canCreateFiles ? {
            _, _ in
            self.createFile()
        } : nil))
        alert.addAction(action: TCAlertAction(text: localize("import"), action: config.canImportMedia ? {
            _, _ in
            self.importMedia()
        } : nil))

        alert.addAction(action: TCAlertAction(text: localize("close"), shouldCloseAlert: true))
    }

    var imagePicked = false

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if (imagePicked) {
            return
        }
        imagePicked = true

        let image = info[.originalImage] as! UIImage

        delegate?.newFileDialog(dialog: self, hasPicked: image)

        picker.dismiss(animated: true, completion: nil)
    }

    internal func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
