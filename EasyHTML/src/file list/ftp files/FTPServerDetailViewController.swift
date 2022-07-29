//
//  FTPServerDetailViewController.swift
//  EasyHTML
//
//  Created by Артем on 17.05.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

// Subclassing ´FTPNewServerDialogTableViewController´, as the principle is almost the same

class FTPServerDetailViewController: FTPNewServerDialogTableViewController {

    override func viewDidLoad() {

        guard sourceServer != nil else {
            fatalError("Expected source server")
        }

        super.viewDidLoad()

        title = localize("editserver", .ftp)

        selectedProtocol = sourceServer.connectionType
        loginTypeIsAnonymous = sourceServer.username == nil

        portValid = true
        nameValid = true
        loginValid = true
        hostValid = true

        preferredHost = sourceServer.host
        preferredName = sourceServer.name
        preferredPort = String(sourceServer.port)
        preferredPath = sourceServer.remotePath
        preferredUsername = sourceServer.username ?? ""
        preferredPassword = sourceServer.password ?? ""

        preferringPassiveConnectionType = sourceServer.ftpConnectionIsPassive
    }
}
