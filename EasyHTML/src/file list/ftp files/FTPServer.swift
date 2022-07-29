//
//  FTPServer.swift
//  EasyHTML
//
//  Created by Артем on 19.05.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit
import NMSSH

internal class FTPServer: NSObject, NSCoding, NSCopying {

    internal enum ConnectionProtocol: Int32 {
        case ftp, sftp
    }

    internal func encode(with aCoder: NSCoder) {
        aCoder.encode(host, forKey: "1")
        aCoder.encodeCInt(connectionType.rawValue, forKey: "2")
        aCoder.encode(username, forKey: "3")
        aCoder.encode(passwordKey, forKey: "4")
        aCoder.encode(name, forKey: "5")
        aCoder.encodeCInt(Int32(port), forKey: "6")
        aCoder.encode(remotePath, forKey: "7")
        aCoder.encode(ftpConnectionIsPassive, forKey: "8")
    }

    internal required init?(coder aDecoder: NSCoder) {
        guard let host = aDecoder.decodeObject(forKey: "1") as? String else {
            return nil
        }
        let connectionType = aDecoder.decodeCInt(forKey: "2")
        guard let connection = ConnectionProtocol(rawValue: connectionType) else {
            return nil
        }
        let username = aDecoder.decodeObject(forKey: "3") as? String
        guard let passwordKey = aDecoder.decodeObject(forKey: "4") as? String else {
            return nil
        }
        guard let name = aDecoder.decodeObject(forKey: "5") as? String else {
            return nil
        }
        let port = Int(aDecoder.decodeCInt(forKey: "6"))
        guard let path = aDecoder.decodeObject(forKey: "7") as? String else {
            return nil
        }
        let ftpConnectionIsPassive = aDecoder.decodeBool(forKey: "8")

        self.host = host
        self.username = username
        self.passwordKey = passwordKey
        self.connectionType = connection
        self.name = name
        self.port = port
        remotePath = path
        self.ftpConnectionIsPassive = ftpConnectionIsPassive
    }

    internal init(name: String, host: String, username: String!, passwordKey: String!) {
        self.name = name
        self.host = host
        self.username = username
        self.passwordKey = passwordKey
    }

    internal init(name: String, host: String, username: String!, password: String!) {
        self.name = name
        self.host = host
        self.username = username

        passwordKey = UUID().uuidString

        if password != nil {
            KeychainService.savePassword(service: FTPServer.service, account: passwordKey, data: password)
        }
    }

    internal func copy(with zone: NSZone? = nil) -> Any {
        let server = FTPServer(name: name, host: host, username: username, password: password)

        server.connectionType = connectionType
        server.port = port
        server.remotePath = remotePath
        server.ftpConnectionIsPassive = ftpConnectionIsPassive

        return server
    }

    private static var service = "jakmobius.easyhtml.serverpasswords"
    internal var host: String;
    internal var connectionType: ConnectionProtocol = .ftp
    internal var username: String!
    internal var passwordKey: String
    internal var name: String
    internal var port: Int = 21
    internal var ftpConnectionIsPassive = false

    /// Server password, stored in a keychain
    internal var password: String! {
        get {
            let password = KeychainService.loadPassword(service: FTPServer.service, account: passwordKey)

            if password == nil {
                return nil
            }

            if password!.isEmpty {
                return nil
            }

            return password!
        }
        set {
            KeychainService.removePassword(service: FTPServer.service, account: passwordKey)

            if newValue != nil {
                KeychainService.savePassword(service: FTPServer.service, account: passwordKey, data: newValue!)
            }
        }
    }

    /// The path to the root folder. Always starts with "/"
    internal var remotePath: String = "/";

    internal func createSession() -> FTPUniversalSession {
        FTPUniversalSession(server: self)
    }

    override func isEqual(_ object: Any?) -> Bool {
        if let server = object as? FTPServer {
            guard server.host == host else {
                return false
            }
            guard server.username == username else {
                return false
            }
            guard server.port == port else {
                return false
            }
            guard server.connectionType == connectionType else {
                return false
            }

            return true
        }
        return false
    }
}

internal class CancellableRequest: NSObject {
    private var cancelBlock: ((CancellableRequest) -> ())!

    internal init(cancelBlock: @escaping (CancellableRequest) -> ()) {
        self.cancelBlock = cancelBlock
    }

    internal func cancel() {
        cancelBlock?(self)
        cancelBlock = nil
    }

    override func copy() -> Any {
        self
    }
}

internal class FTPFile: FSNode.File {
    override internal var size: Int64 {
        get {
            _size
        }
    }

    internal var modificationDate: Date!

    private var _size: Int64

    private override init(url: URL, sourceType: FileSourceType) {
        _size = -1
        super.init(url: url)
        self.sourceType = sourceType
    }

    private override init(url: URL) {
        fatalError()
    }

    internal init(url: URL, size: Int64, sourceType: FileSourceType) {
        _size = size
        super.init(url: url)
        self.sourceType = sourceType
    }

    required init(from decoder: Decoder) throws {
        _size = -1
        try super.init(from: decoder)
    }

    internal override func isEqual(_ object: Any?) -> Bool {
        if let file = object as? FTPFile {
            return file.url == url
        }
        return false
    }
}

internal class FTPFolder: FSNode.Folder {
    override internal var countOfFilesInside: Int {
        get {
            -1
        }
    }

    internal override init(url: URL, sourceType: FileSourceType) {
        super.init(url: url)

        self.sourceType = sourceType
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    internal override func isEqual(_ object: Any?) -> Bool {
        if let folder = object as? FTPFolder {
            return folder.url == url
        }
        return false
    }

    internal var modificationDate: Date!
}

internal class FTPShortcut: FSNode.Shortcut {
    internal override func isEqual(_ object: Any?) -> Bool {
        if let folder = object as? FTPShortcut {
            return folder.url == url
        }
        return false
    }
}
