//
//  FTPFileLIstTableView + FileDetailDelegate.swift
//  EasyHTML
//
//  Created by Артем on 22/10/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

extension FTPFileListTableView: FileDetailDelegate, FileDetailDataSource {
    func fileDetail(sourceNameOf file: FSNode) -> String {
        server?.name ?? localize("remoteserver", .ftp)
    }

    func fileDetail(sizeOf file: FSNode, completion: @escaping (Int64) -> ()) -> CancellableRequest! {
        if let file = file as? FTPFile {
            completion(file.size)
            return nil
        } else if let folder = file as? FTPFolder {
            return session.calculateFolderSizeAsync(folder: folder, completion: { (size, error) in
                completion(size ?? -1)
            })
        }
        completion(-1)
        return nil
    }

    func fileDetail(sizeOf file: FSNode) -> Int64 {
        if let file = file as? FTPFile {
            return file.size
        }
        return -1
    }

    func fileDetail(creationDateOf file: FSNode) -> Date? {
        nil
    }

    func fileDetail(pathTo file: FSNode) -> String {
        let path = url.path
        let serverPath = server.remotePath

        return String(path.suffix(path.count - serverPath.count))
    }

    func fileDetail(modificationDateOf file: FSNode) -> Date? {
        if let file = file as? FTPFile {
            return file.modificationDate
        } else if let file = file as? FTPFolder {
            return file.modificationDate
        } else {
            return nil
        }
    }

    func fileDetail(controller: FileDetailViewController, shouldDelete file: FSNode) {
        fileList(deleted: file)
    }

    func fileDetail(controller: FileDetailViewController, shouldRename file: FSNode, to newName: String) {
        let alert = NetworkOperationDialog()
        alert.alert.header.text = localize("renaming", .files)

        func startRequest() {
            alert.operationStarted()

            let path = url.appendingPathComponent(getAvailableFileName(fileName: newName)).path

            let request = session.moveFileAsync(file: file, to: path, errorHandler: {
                error, callback in

                let alert = TCAlertController.getNew()

                alert.applyDefaultTheme()

                alert.contentViewHeight = 50
                alert.constructView()

                alert.addTextView().text = error.localizedDescription

                alert.header.text = localize("copyingerror")

                alert.addAction(action: TCAlertAction(text: localize("tryagain"), action: { (_, _) in
                    callback(.tryAgain)
                }, shouldCloseAlert: true))
                alert.addAction(action: TCAlertAction(text: localize("skipfile"), action: { (_, _) in
                    callback(.skip)
                }, shouldCloseAlert: true))
                alert.addAction(action: TCAlertAction(text: localize("stopcopying"), action: { (_, _) in
                    callback(.stop)
                }, shouldCloseAlert: true))

                self.view.window!.addSubview(alert.view)
            }) { error in
                if error == nil {
                    alert.operationCompleted()

                    self.reloadDirectory(animated: true)

                    Editor.fileMoved(file: file, to: self.url.appendingPathComponent(newName))
                } else {
                    alert.operationFailed(with: error, retryHandler: {
                        startRequest()
                    })
                }
            }

            if request != nil {
                alert.cancelHandler = {
                    request?.cancel()
                }

                alert.alert.buttons.first!.isEnabled = true
            } else {
                alert.alert.buttons.first!.isEnabled = false
            }
        }

        alert.present(on: view.window!)

        startRequest()
    }

    func fileDetail(controller: FileDetailViewController, shouldMove file: FSNode) {
        if let index = files.firstIndex(of: file) {
            selectFileToRelocate(at: IndexPath(row: index, section: 0))
        }
    }

    func fileDetail(controller: FileDetailViewController, shouldClone file: FSNode) {
        cloneFile(file: file)
    }
}
