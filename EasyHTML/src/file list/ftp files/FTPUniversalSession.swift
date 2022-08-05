//
//  FTPUniversalSession.swift
//  EasyHTML
//
//  Created by Артем on 04/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation
import NMSSH

/// Universal thread-safe session for file management on remote servers via ´ftp´, ´ftps´ and ´sftp´ protocols
internal class FTPUniversalSession: NSObject, NSCopying {

    // We don't need the ´host´ field when we use the SFTP connection, so it is optional

    var filenameEncoding: String.Encoding = .utf8
    private var username: String! = nil
    private var hostname: String! = nil
    private var password: String! = nil
    private var fullhost: String! = nil
    private var passive: Bool! = false
    private var port: Int! = nil

    private(set) var sourceType: FileSourceType

    internal let sshSession: NMSSHSession!

    private(set) var proto: FTPServer.ConnectionProtocol

    private var error: Error? {
        let error = sshSession?.lastError

        if let error = error, (error as NSError).code == LIBSSH2_ERROR_NONE {
            return NSError(domain: "libssh2", code: Int(LIBSSH2_ERROR_NONE), userInfo: [NSLocalizedDescriptionKey: "No active session"])
        }

        return error
    }

    func decodeFTPFileName(filename: String) -> String! {
        if filenameEncoding == .macOSRoman {
            return filename
        } else if let data = filename.data(using: .macOSRoman) {
            return String(data: data, encoding: filenameEncoding)
        }
        return nil
    }

    func encodeFTPFileName(filename: String) -> String! {
        if filenameEncoding == .macOSRoman {
            return filename
        } else if let data = filename.data(using: filenameEncoding) {
            return String(data: data, encoding: .macOSRoman)
        }
        return nil
    }

    private var isolationQueue: DispatchQueue!

    private func tryToReconnectSSH() -> Error? {
        if let session = sshSession {
            session.disconnect()
            if !session.connect() {
                return session.lastError
            }

            session.authenticate(byPassword: password)

            if !session.isAuthorized {
                return error
            }
        }
        return nil
    }

    private var sftpConnectionTimeout: TimeInterval = 60 // 1 minute
    private var sftpDisconnectionDate: Date! = nil
    private var sftpSession: NMSFTP! = nil

    private func sftpConnect() -> Error! {

        if let session = sftpSession {
            if (sftpDisconnectionDate != nil) {
                if (Date().timeIntervalSince(sftpDisconnectionDate) > sftpConnectionTimeout) {
                    sftpSession = nil
                }
            }

            if (session.isConnected) {
                return nil
            }

            // Try to reconnect
        }

        if let session = sshSession {
            if !session.isConnected {
                if !sshSession.connect() {
                    return sshSession.lastError
                }
            }
            if !session.isAuthorized {
                if !sshSession.authenticate(byPassword: password) {
                    return error
                }
            }
            if !session.sftp.connect() {
                print("[EasyHTML] [FTPUniversalSession] Failed to init SFTP session! Reconnecting to server...")
                if let error = tryToReconnectSSH() {
                    print("[EasyHTML] [FTPUniversalSession] Reconnect failed! Perhaps, the internet connection is lost or server not found")
                    return error
                } else {
                    print("[EasyHTML] [FTPUniversalSession] Reconnect succeeded. Trying to init SFTP session...")
                    if !session.sftp.connect() {

                        print("[EasyHTML] [FTPUniversalSession] Failed to init SFTP session")

                        // Seems like this server does not support SFTP.
                        // TODO: Make localized version of these errors

                        return NSError(domain: "libssh2", code: -9283, userInfo: [NSLocalizedDescriptionKey: "Connection succeeded, but failed to init SFTP session on this server"])
                    }

                    print("[EasyHTML] [FTPUniversalSession] SFTP session succeeded. Connection restored")

                    sftpSession = session.sftp

                    return nil
                }
            }

            sftpSession = session.sftp
        }

        return nil
    }

    private func sftpDisconnect() {
        sftpDisconnectionDate = Date()
        // if let session = sshSession, session.sftp.isConnected {
        //     session.sftp.disconnect()
        // }
    }

    internal init(server: FTPServer) {
        password = server.password
        username = server.username
        proto = server.connectionType
        fullhost = server.host + ":\(server.port)"
        hostname = server.host
        port = server.port
        passive = server.ftpConnectionIsPassive
        sourceType = .ftp(server: server)

        isolationQueue = DispatchQueue(label: "easyhtml.ftpqueue-\(UUID().uuidString)", attributes: .concurrent)

        if proto == .sftp {
            sshSession = NMSSHSession(host: hostname, port: port, andUsername: username)
        } else {
            sshSession = nil
        }
    }

    internal func createFolderAsync(path: String, completion: ((Error?) -> ())? = nil) {

        switch proto {
        case .sftp:

            let session = sshSession!

            isolationQueue.async(flags: .barrier) {
                if let error = self.sftpConnect() {
                    completion?(error)
                    return
                }

                let result = session.sftp.createDirectory(atPath: path)


                if result {
                    DispatchQueue.main.async {
                        completion?(nil)
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        completion?(session.lastError)
                    })
                }

                self.sftpDisconnect()
            }

        case .ftp:

            let request = WRRequestCreateDirectory()

            configureWRRequest(request: request)

            request.path = path

            request.completion = {
                success in
                request.completion = nil
                if success {
                    completion?(nil)
                } else {
                    completion?(request.error?.nsError)
                }
            }

            DispatchQueue.main.async {
                request.start()
            }
        }
    }

    private enum Resource {
        case file(path: String, size: Int64), folder(path: String)
    }

    private func getAllFolderResources(path: String, progress: @escaping (UInt64) -> Bool, prefix: String = "") -> (error: Error?, result: [Resource]?) {

        var path = path
        var prefix = prefix

        if !path.hasPrefix("/") {
            path = "/" + path
        }
        if !path.hasSuffix("/") {
            path += "/"
        }
        if prefix.hasSuffix("/") {
            prefix.remove(at: prefix.endIndex)
        }

        switch proto {
        case .sftp:

            // Assuming session is created and we're in an isolation task

            let session = sshSession!
            var result = [Resource]()
            if let contents = session.sftp.contentsOfDirectory(atPath: prefix + path) {

                var counted: UInt64 = 0

                for file in contents {
                    let permissions = file.permissions!
                    let path = path + file.filename

                    if permissions.first == "d" {

                        let subdirectory = getAllFolderResources(path: path, progress: { subcounted in
                            progress(counted + subcounted)
                        }, prefix: prefix)

                        if let error = subdirectory.error {
                            return (error: error, result: nil)
                        }

                        guard let subresult = subdirectory.result else {
                            return (error: nil, result: nil)
                        }

                        result.append(contentsOf: subresult)

                        counted += UInt64(subresult.count)

                        if !progress(counted) {
                            return (error: nil, result: [])
                        }
                    } else {
                        result.append(.file(path: path, size: file.fileSize!.int64Value))
                    }

                    counted += 1
                }

                result.append(.folder(path: path))

                return (error: nil, result: result)

            } else if let error = error {
                let nsError = error as NSError
                var userInfo = nsError.userInfo

                let localizedDescription = (userInfo[NSLocalizedDescriptionKey] as? String ?? "Unknown error")

                if path != "/" {
                    userInfo[NSLocalizedDescriptionKey] = localizedDescription + " at path \(path)"
                } else {
                    userInfo[NSLocalizedDescriptionKey] = localizedDescription
                }

                let newError = NSError(domain: nsError.domain, code: nsError.code, userInfo: userInfo)
                return (error: newError, result: nil)
            }

            return (error: nil, result: nil)

        case .ftp:

            let request = WRRequestListDirectory()

            configureWRRequest(request: request)

            request.path = prefix + path

            var result: [Resource]! = nil
            var error: Error! = nil
            var counted: UInt64 = 0

            let success = runWRRequestSync(request: request)

            if success {
                result = []

                for info in request.filesInfo {
                    if let info = info as? Dictionary<String, Any> {
                        guard let type = info["kCFFTPResourceType"] as? Int32 else {
                            continue
                        }
                        guard let name = info["kCFFTPResourceName"] as? String else {
                            continue
                        }
                        guard name != "." && name != ".." else {
                            continue
                        }

                        guard let decodedName = decodeFTPFileName(filename: name) else {
                            continue
                        }

                        if type == DT_DIR {

                            var subdirectory: (error: Error?, result: [Resource]?)

                            subdirectory = getAllFolderResources(path: path + decodedName, progress: { subCounted in
                                progress(counted + subCounted)
                            }, prefix: prefix)
                            if let subError = subdirectory.error {
                                result = nil
                                return (error: subError, result: nil)
                            }

                            guard let subResult = subdirectory.result else {
                                return (error: nil, result: nil)
                            }

                            result.append(contentsOf: subResult)

                            counted += UInt64(subResult.count)

                            if !progress(counted) {
                                return (error: nil, result: nil)
                            }

                        } else {
                            let size = (info["kCFFTPResourceSize"] as? Int64) ?? Int64(-1)
                            result.append(.file(path: path + decodedName, size: size))
                        }
                    }

                    counted += 1
                }

                result.append(.folder(path: path))
            } else {
                error = request.error.nsError
            }

            if let error = error {
                let nsError = error as NSError
                var userInfo = nsError.userInfo

                let localizedDescription = (userInfo[NSLocalizedDescriptionKey] as? String ?? "Unknown error")

                if path != "/" {
                    userInfo[NSLocalizedDescriptionKey] = localizedDescription + " at path \(path)"
                } else {
                    userInfo[NSLocalizedDescriptionKey] = localizedDescription
                }

                let newError = NSError(domain: nsError.domain, code: nsError.code, userInfo: userInfo)
                return (error: newError, result: nil)
            }

            return (error: nil, result: result)
        }
    }

    internal enum FolderDeletionState {
        case countingFiles(counted: UInt64), deletingFiles(deleted: UInt64, total: UInt64)
    }

    internal enum FolderCopyingState {
        case countingFiles(counted: UInt64), copyingFiles(copied: UInt64, total: UInt64)
    }

    /// Runs the specified `WRRequest` synchronously with the current thread, using `DispatchSemaphore`.
    /// - returns: a boolean indicating whether request was successfuly completed

    private func runWRRequestSync(request: WRRequest) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        request.completion = {
            _success in
            request.completion = nil
            success = _success
            semaphore.signal()
        }

        if Thread.isMainThread {
            request.start()
        } else {
            DispatchQueue.main.sync {
                request.start()
            }
        }

        semaphore.wait()

        return success
    }

    private func configureWRRequest(request: WRRequest) {
        request.username = username
        request.password = password
        request.hostname = fullhost
        request.passive = passive
    }

    struct FTPError: LocalizedError {
        let filename: String
        let error: Error

        var localizedDescription: String {
            localize("failedtocopyfile")
                    .replacingOccurrences(of: "#", with: filename)
                    .appending("\n").appending(error.localizedDescription)
        }

        var errorDescription: String? {
            localizedDescription
        }
    }

    func calculateFolderSizeAsync(folder: FTPFolder, completion: ((Int64?, Error?) -> ())?) -> CancellableRequest {

        var running = true

        func evaluate() {

            let result = getAllFolderResources(path: "", progress: { (count) in
                running
            }, prefix: folder.url.path)

            if !running {
                return
            }

            if let error = result.error {
                DispatchQueue.main.async {
                    completion?(nil, error)
                }
                return
            }

            guard let items = result.result else {
                DispatchQueue.main.async {
                    completion?(nil, nil)
                }
                return
            }

            var size: Int64 = 0

            for item in items {
                if case .file(_, let filesize) = item {
                    size += filesize
                }
            }

            if !running {
                return
            }

            DispatchQueue.main.async {
                completion?(size, nil)
            }
        }

        switch proto {
        case .sftp:
            isolationQueue.async(flags: .barrier) {

                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion?(nil, error)
                    }
                    return
                }

                evaluate()

                self.sftpDisconnect()
            }
        case .ftp:
            isolationQueue.async {
                evaluate()
            }
        }

        return CancellableRequest {
            _ in
            running = false
        }
    }

    typealias ErrorHandlerCallback = ((Error, @escaping (RelocationErrorRestoreType) -> ()) -> ())?

    private func downloadFolderFTP(folder: FTPFolder, to path: String, errorHandler: ErrorHandlerCallback, completion: ((Error?) -> ())?, progress: ((Float) -> ())? = nil) -> CancellableRequest! {

        var running = true
        var currentRequest: WRRequest! = nil
        guard let url = URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else {
            return nil
        }

        isolationQueue.async {
            let result = self.getAllFolderResources(path: "", progress: { (count) in
                running
            }, prefix: folder.url.path)

            if !running {
                return
            }

            if let error = result.error {
                DispatchQueue.main.async {
                    completion?(error)
                }
                return
            }

            // File list should be inverted, so folders are created before files get their place inside them.

            guard let resources = result.result?.reversed() else {
                return
            }

            var copied: Float = 0
            var ignore: String? = nil

            var iterator = resources.makeIterator()

            func nextRequest() -> Bool {

                guard let resource = iterator.next() else {
                    DispatchQueue.main.async {
                        completion?(nil)
                    }
                    return false
                }

                func evaluate() -> Bool {
                    func errorOccurred(error: Error) {
                        DispatchQueue.main.async {
                            if errorHandler == nil {
                                completion?(error)
                            } else {
                                errorHandler!(error) {
                                    restoreType in
                                    self.isolationQueue.async(flags: .barrier) {
                                        switch restoreType {
                                        case .stop:
                                            DispatchQueue.main.async {
                                                completion?(nil)
                                            }
                                        case .skip:
                                            if case let .folder(path) = resource {
                                                ignore = path
                                            }
                                            copied += 1
                                            continueIteration()
                                        case .tryAgain:
                                            if evaluate() {
                                                continueIteration()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    switch resource {
                    case .file(let filePath, _):

                        let fileUrl = url.appendingPathComponent(filePath)
                        let sourceUrl = folder.url.appendingPathComponent(filePath)

                        if (ignore != nil) {
                            if (filePath.hasPrefix(ignore!)) {
                                return true
                            } else {
                                ignore = nil
                            }
                        }

                        let request = WRRequestDownload()

                        self.configureWRRequest(request: request)

                        request.receivedFile = fileUrl
                        request.path = sourceUrl.path

                        currentRequest = request

                        let success = self.runWRRequestSync(request: request)

                        currentRequest = nil

                        if !success {
                            let error = FTPError(filename: sourceUrl.lastPathComponent, error: request.error.nsError!)
                            errorOccurred(error: error)

                            return false
                        }

                        copied += 1

                    case .folder(let folderPath):

                        let folderUrl = url.appendingPathComponent(folderPath)
                        let sourceUrl = folder.url.appendingPathComponent(folderPath)

                        if (ignore != nil) {
                            if (folderPath.hasPrefix(ignore!)) {
                                return true
                            } else {
                                ignore = nil
                            }
                        }

                        do {
                            try FileManager.default.createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                            let error = FTPError(filename: sourceUrl.lastPathComponent, error: error)
                            errorOccurred(error: error)

                            return false
                        }

                        copied += 1
                    }

                    return running
                }

                return evaluate()
            }

            func continueIteration() {
                while nextRequest() {
                }
            }

            continueIteration()
        }

        return CancellableRequest {
            _ in
            currentRequest?.destroy()
            running = false
        }
    }

    private func downloadFolderSFTP(folder: FTPFolder, to path: String, errorHandler: ErrorHandlerCallback, completion: ((Error?) -> ())?, progress: ((Float) -> ())? = nil) -> CancellableRequest! {

        let sourcePath = folder.url.path
        let url = URL(fileURLWithPath: path)
        let session = sshSession!
        var running = true

        isolationQueue.async(flags: .barrier, execute: {

            if let error = self.sftpConnect() {
                DispatchQueue.main.async {
                    completion?(error)
                }
                return
            }

            let result = self.getAllFolderResources(path: "", progress: { _ in
                running
            }, prefix: folder.url.path)

            if !running {
                self.sftpDisconnect()
                return
            }

            if let error = result.error {
                DispatchQueue.main.async {
                    completion?(error)
                }
                return
            }

            // TODO: Duplicated code
            // File list should be inverted, so folders are created before files get their place inside them.

            guard let resources = result.result?.reversed() else {
                return
            }
            var iterator = resources.makeIterator()
            let totalResults = Float(resources.count)
            var downloaded: Float = 0
            var ignore: String?

            func finish(_ error: Error! = nil) {
                DispatchQueue.main.async {
                    completion?(error)
                }
                self.sftpDisconnect()
            }

            /// Downloads next resource from the server
            /// - Returns: Boolaen indicating whether there are more resources to download
            func nextResource() -> Bool {

                guard let resource = iterator.next() else {
                    finish()
                    return false
                }

                DispatchQueue.main.async {
                    progress?(downloaded / totalResults)
                }

                func evaluate() -> Bool {

                    func errorOccurred(error: Error) {
                        DispatchQueue.main.async {
                            if errorHandler == nil {
                                finish(error)
                            } else {
                                errorHandler!(error) {
                                    restoreType in
                                    self.isolationQueue.async(flags: .barrier) {
                                        switch restoreType {
                                        case .stop:
                                            finish(nil)
                                        case .skip:
                                            if case let .folder(path) = resource {
                                                ignore = path
                                            }
                                            downloaded += 1
                                            continueIteration()
                                        case .tryAgain:
                                            if evaluate() {
                                                continueIteration()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    switch resource {
                    case .file(let filePath, _):

                        if ignore != nil {
                            if (filePath.hasPrefix(ignore!)) {
                                return true
                            } else {
                                ignore = nil
                            }
                        }

                        let fileUrl = url.appendingPathComponent(filePath)
                        let outputStream = OutputStream(url: url.appendingPathComponent(filePath), append: false)!
                        
                        if(!session.sftp.contents(atPath: sourcePath + filePath, to: outputStream, progress: {
                            _, _ in
                            running
                        })) {

                            let error = FTPError(filename: fileUrl.lastPathComponent, error: self.error!)
                            errorOccurred(error: error)

                            return false
                        }

                    case .folder(let folderPath):

                        if ignore != nil {
                            if (folderPath.hasPrefix(ignore!)) {
                                return true
                            } else {
                                ignore = nil
                            }
                        }

                        let folderUrl = url.appendingPathComponent(folderPath)

                        do {
                            try FileManager.default.createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                            let error = FTPError(filename: folderUrl.lastPathComponent, error: error)
                            errorOccurred(error: error)
                            return false
                        }
                    }

                    if !running {
                        self.sftpDisconnect()
                        return false
                    }

                    downloaded += 1

                    return true
                }

                return evaluate()
            }


            func continueIteration() {
                while nextResource() {
                }
            }

            continueIteration()
        })

        return CancellableRequest {
            _ in
            running = false
        }
    }

    @discardableResult internal func downloadFolder(folder: FTPFolder, to path: String, errorHandler: ErrorHandlerCallback, completion: ((Error?) -> ())? = nil, progress: ((Float) -> ())? = nil) -> CancellableRequest! {

        switch proto {
        case .sftp:
            return downloadFolderSFTP(folder: folder, to: path, errorHandler: errorHandler, completion: completion, progress: progress)
        case .ftp:
            return downloadFolderFTP(folder: folder, to: path, errorHandler: errorHandler, completion: completion, progress: progress)
        }
    }

    @discardableResult internal func copyFolderRecursivelyAsync(folder: FTPFolder, to path: String, progress: ((FolderCopyingState) -> ())? = nil, errorHandler: ErrorHandlerCallback, completion: ((Error?) -> ())? = nil, prefix: String = "") -> CancellableRequest! {
        var sourcePath = folder.url.path

        if sourcePath.hasSuffix("/") {
            sourcePath.removeLast()
        }

        switch proto {
        case .sftp:

            let session = sshSession!
            var running = true

            isolationQueue.async(flags: .barrier) {

                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion?(error)
                    }
                    return
                }

                DispatchQueue.main.async {
                    progress?(.countingFiles(counted: 0))
                }

                let result = self.getAllFolderResources(path: "", progress: { (count) in
                    DispatchQueue.main.async {
                        progress?(.countingFiles(counted: count))
                    }
                    return running
                }, prefix: folder.url.path)

                if !running {
                    self.sftpDisconnect()
                    return
                }

                if let error = result.error {
                    DispatchQueue.main.async {
                        completion?(error)
                    }
                    return
                }

                func finish(_ error: Error! = nil) {
                    DispatchQueue.main.async {
                        completion?(error)
                    }
                    self.sftpDisconnect()
                }

                // TODO: Duplicated code
                // File list should be inverted, so folders are created before files get their place inside them.

                guard let resources = result.result?.reversed() else {
                    return
                }
                let totalResults = UInt64(resources.count)
                var iterator = resources.makeIterator()
                // Stores path to the directory that caused the error
                var ignore: String?

                var cloned: UInt64 = 0

                func nextRequest() -> Bool {
                    guard let resource = iterator.next() else {
                        finish()
                        return false
                    }

                    DispatchQueue.main.async {
                        progress?(.copyingFiles(copied: cloned, total: totalResults))
                    }

                    func evaluate() -> Bool {

                        func errorOccurred(error: Error) {
                            if errorHandler == nil {
                                finish(error)
                            } else {
                                DispatchQueue.main.async {
                                    errorHandler!(error) {
                                        restoreType in

                                        self.isolationQueue.async(flags: .barrier) {
                                            switch restoreType {
                                            case .stop:
                                                finish()
                                            case .skip:
                                                if case let .folder(path) = resource {
                                                    ignore = path
                                                }
                                                cloned += 1
                                                continueIteration()
                                            case .tryAgain:
                                                if evaluate() {
                                                    continueIteration()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        switch resource {
                        case .file(let filePath, _):

                            if ignore != nil {
                                if (filePath.hasPrefix(ignore!)) {
                                    return true
                                } else {
                                    ignore = nil
                                }
                            }

                            let success = session.sftp.copyContents(ofPath: sourcePath + filePath, toFileAtPath: path + filePath, progress: {
                                (written, total) -> Bool in

                                running
                            })

                            if !success {
                                // Ask user what to do
                                // Finish current task by returning false

                                let filename = URL(fileURLWithPath: sourcePath + filePath).lastPathComponent
                                let error = FTPError(filename: filename, error: self.error!)

                                errorOccurred(error: error)

                                return false
                            }

                        case .folder(let folderPath):

                            if ignore != nil {
                                if (folderPath.hasPrefix(ignore!)) {
                                    return true
                                } else {
                                    ignore = nil
                                }
                            }

                            let success = session.sftp.createDirectory(atPath: path + folderPath)

                            if !success {
                                // Ask user what to do
                                // Finish current task by returning false

                                let filename = URL(fileURLWithPath: sourcePath + folderPath).lastPathComponent
                                let error = FTPError(filename: filename, error: self.error!)

                                errorOccurred(error: error)

                                return false
                            }
                        }

                        if !running {
                            self.sftpDisconnect()
                            return false
                        }

                        cloned += 1

                        return true
                    }

                    return evaluate()
                }

                func continueIteration() {
                    while nextRequest() {
                    }
                }

                continueIteration()
            }

            return CancellableRequest {
                _ in
                running = false
            }

        case .ftp:

            var running = true
            var currentRequest: WRRequest!
            var ignore: String?

            isolationQueue.async {

                DispatchQueue.main.async {
                    progress?(.countingFiles(counted: 0))
                }

                let result = self.getAllFolderResources(path: "", progress: { counted -> Bool in

                    DispatchQueue.main.async {
                        progress?(.countingFiles(counted: counted))
                    }
                    return running
                }, prefix: sourcePath)

                if let error = result.error {
                    DispatchQueue.main.async {
                        completion?(error)
                    }

                    return
                }

                // TODO: Duplicated code
                // File list should be inverted, so folders are created before files get their place inside them.

                guard let resources = result.result?.reversed() else {
                    return
                }

                let totalResults = UInt64(result.result!.count)
                var iterator = resources.makeIterator()
                var cloned: UInt64 = 0

                func finish(_ error: Error! = nil) {
                    DispatchQueue.main.async {
                        progress?(.copyingFiles(copied: totalResults, total: totalResults))
                        completion?(error)
                    }

                    self.sftpDisconnect()
                }

                func nextRequest() -> Bool {

                    guard let resource = iterator.next() else {
                        finish()
                        return false
                    }

                    func evaluate() -> Bool {

                        func errorOccurred(error: Error) {
                            if errorHandler == nil {
                                finish(error)
                            } else {
                                DispatchQueue.main.async {
                                    errorHandler!(error) {
                                        restoreType in

                                        self.isolationQueue.async(flags: .barrier) {
                                            switch restoreType {
                                            case .stop:
                                                finish()
                                            case .skip:
                                                if case let .folder(path) = resource {
                                                    ignore = path
                                                }
                                                cloned += 1
                                                continueIteration()
                                            case .tryAgain:
                                                if evaluate() {
                                                    continueIteration()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Inform the user about our progress

                        DispatchQueue.main.async {
                            progress?(.copyingFiles(copied: cloned, total: totalResults))
                        }

                        switch resource {
                        case .file(let filePath, _):

                            if ignore != nil {
                                if filePath.hasPrefix(ignore!) {
                                    return true
                                } else {
                                    ignore = nil
                                }
                            }

                            let downloadRequest = WRRequestDownload()
                            self.configureWRRequest(request: downloadRequest)
                            downloadRequest.path = sourcePath + filePath
                            currentRequest = downloadRequest
                            if !self.runWRRequestSync(request: downloadRequest) {
                                errorOccurred(error: downloadRequest.error.nsError)

                                return false
                            }

                            if !running {
                                self.sftpDisconnect()
                                return false
                            }

                            let uploadRequest = WRRequestUpload()
                            self.configureWRRequest(request: uploadRequest)
                            uploadRequest.path = path + filePath
                            uploadRequest.dataStream = InputStream(fileAtPath: downloadRequest.receivedFile.path)
                            currentRequest = uploadRequest

                            if !self.runWRRequestSync(request: uploadRequest) {
                                errorOccurred(error: uploadRequest.error.nsError)

                                return false
                            }

                            try? FileManager.default.removeItem(at: downloadRequest.receivedFile)
                        case .folder(let folderPath):

                            if ignore != nil {
                                if folderPath.hasPrefix(ignore!) {
                                    return true
                                } else {
                                    ignore = nil
                                }
                            }

                            let request = WRRequestCreateDirectory()
                            self.configureWRRequest(request: request)
                            request.path = path + folderPath
                            currentRequest = request
                            if !self.runWRRequestSync(request: request) {
                                errorOccurred(error: request.error.nsError)

                                return false
                            }
                        }

                        if !running {
                            finish()
                            return false
                        }

                        cloned += 1

                        return true
                    }

                    return evaluate()
                }

                func continueIteration() {
                    while nextRequest() {
                    }
                }

                continueIteration()

                DispatchQueue.main.async {
                    progress?(.copyingFiles(copied: totalResults, total: totalResults))
                    completion?(nil)
                }
            }

            return CancellableRequest {
                _ in
                running = false
                currentRequest?.destroy()
            }
        }
    }

    /// Renames a file on the remote server.
    /// - note: SFTP supports renaming directories. FTP and FTPS only support renaming files.
    @discardableResult internal func moveFileAsync(file: FSNode, to path: String, errorHandler: FTPUniversalSession.ErrorHandlerCallback, completion: ((Error?) -> ())? = nil) -> CancellableRequest! {
        moveFileAsync(file: file.url.path, isDirectory: file is FTPFolder, to: path, errorHandler: errorHandler, completion: completion)
    }

    /// Moves a file on the remote server.
    /// - note: SFTP supports renaming directories. FTP and FTPS only support renaming files.
    @discardableResult internal func moveFileAsync(file: String, isDirectory: Bool, to path: String, errorHandler: FTPUniversalSession.ErrorHandlerCallback, completion: ((Error?) -> ())? = nil) -> CancellableRequest! {
        switch proto {
        case .sftp:
            let session = sshSession!

            isolationQueue.async(flags: .barrier) {
                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion?(error)
                    }
                    return
                }

                let success = session.sftp.moveItem(atPath: file, toPath: path)

                self.sftpDisconnect()

                DispatchQueue.main.async {
                    if success {
                        completion?(nil)
                    } else {
                        completion?(self.error)
                    }
                }
            }

            return nil
        case .ftp:

            if !isDirectory {
                let request = WRRequestDownload()
                let uploadRequest = WRRequestUpload()
                let deleteRequest = WRRequestDelete()

                configureWRRequest(request: request)
                configureWRRequest(request: uploadRequest)
                configureWRRequest(request: deleteRequest)

                request.path = file
                uploadRequest.path = path
                deleteRequest.path = file

                request.completion = {
                    success in
                    request.completion = nil
                    if !success {
                        completion?(request.error.nsError)
                        return
                    }
                    uploadRequest.dataStream = InputStream(fileAtPath: request.receivedFile!.path)
                    uploadRequest.completion = {
                        success in
                        uploadRequest.completion = nil
                        if !success {
                            completion?(uploadRequest.error.nsError)
                            return
                        }
                        try? FileManager.default.removeItem(at: request.receivedFile)

                        deleteRequest.completion = {
                            _ in
                            deleteRequest.completion = nil
                            completion?(nil)
                        }
                        deleteRequest.start()
                    }

                    uploadRequest.start()
                }

                request.start()

                return CancellableRequest {
                    _ in
                    request.destroy()
                    uploadRequest.destroy()
                    deleteRequest.destroy()
                }

            } else {

                let folder = FTPFolder(
                        url: URL(string: file.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!,
                        sourceType: sourceType
                )

                copyFolderRecursivelyAsync(folder: folder, to: path, progress: nil, errorHandler: errorHandler, completion: {
                    error in

                    if let error = error {
                        DispatchQueue.main.async {
                            completion?(error)
                        }
                    } else {
                        self.deleteFolderRecursivelyAsync(folder: folder, progress: nil, completion: { error in
                            DispatchQueue.main.async {
                                completion?(nil)
                            }
                        })
                    }
                })
            }
        }

        return nil
    }

    struct FTPFileDeletionFailed: LocalizedError {
        var wrError: WRRequestError
        var fileName: String

        var errorDescription: String? {
            localizedDescription
        }

        var localizedDescription: String {
            localize("failedtodeletefile").replacingOccurrences(of: "#", with: fileName) + "\n" + String(wrError.message ?? "")
        }
    }

    @discardableResult internal func deleteFolderRecursivelyAsync(folder: FTPFolder, progress: ((FolderDeletionState) -> ())? = nil, completion: ((Error?) -> ())? = nil) -> CancellableRequest! {

        switch proto {
        case .sftp:

            let session = sshSession!
            var running = true

            isolationQueue.async(flags: .barrier) {

                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion?(error)
                    }
                    return
                }

                DispatchQueue.main.async {
                    progress?(.countingFiles(counted: 0))
                }

                let result = self.getAllFolderResources(path: folder.url.path, progress: { (count) in
                    DispatchQueue.main.async {
                        progress?(.countingFiles(counted: count))
                    }
                    return running
                })

                if !running {
                    self.sftpDisconnect()
                    return
                }

                if let error = result.error {
                    DispatchQueue.main.async {
                        completion?(error)
                    }
                    return
                }

                let totalResults = UInt64(result.result!.count)

                var deleted: UInt64 = 0

                for resource in result.result! {

                    // Inform the user about our progress

                    DispatchQueue.main.async {
                        progress?(.deletingFiles(deleted: deleted, total: totalResults))
                    }

                    switch resource {
                    case .file(let path, _):
                        if !session.sftp.removeFile(atPath: path) {
                            completion?(self.error)
                        }
                    case .folder(let path):
                        if !session.sftp.removeDirectory(atPath: path) {
                            completion?(self.error)
                        }
                    }

                    if !running {
                        return
                    }

                    deleted += 1
                }

                self.sftpDisconnect()

                DispatchQueue.main.async {
                    completion?(nil)
                }
            }

            return CancellableRequest {
                _ in
                running = false
            }

        case .ftp:
            var running = true

            isolationQueue.async {

                DispatchQueue.main.async {
                    progress?(.countingFiles(counted: 0))
                }

                let result = self.getAllFolderResources(path: folder.url.path, progress: { counted -> Bool in

                    DispatchQueue.main.async {
                        progress?(.countingFiles(counted: counted))
                    }
                    return running
                })

                if let error = result.error {
                    DispatchQueue.main.async {
                        completion?(error)
                    }

                    return
                }

                guard let resources = result.result else {
                    return
                }
                let totalResults = UInt64(result.result!.count)
                var deleted: UInt64 = 0

                for resource in resources {

                    // Inform the user about our progress

                    DispatchQueue.main.async {
                        progress?(.deletingFiles(deleted: deleted, total: totalResults))
                    }

                    let request = WRRequestDelete()

                    self.configureWRRequest(request: request)

                    switch resource {
                    case .file(let filePath, _): request.path = filePath
                    case .folder(let folderPath): request.path = folderPath
                    }

                    if !self.runWRRequestSync(request: request) {
                        DispatchQueue.main.async {

                            if let error = request.error {

                                let fileName = URL(fileURLWithPath: request.path).lastPathComponent

                                let error = FTPFileDeletionFailed(wrError: error, fileName: fileName)

                                completion?(error)

                                return
                            }

                            completion?(nil)
                        }
                        return
                    }

                    if !running {
                        return
                    }

                    deleted += 1
                }

                DispatchQueue.main.async {
                    progress?(.deletingFiles(deleted: totalResults, total: totalResults))
                    completion?(nil)
                }
            }

            return CancellableRequest {
                _ in
                running = false
            }
        }

    }

    /// Deletes file from a server
    @discardableResult internal func deleteFileAsync(file: FSNode, completion: ((Error?) -> ())? = nil) -> CancellableRequest! {

        let path = file.url.path

        switch proto {
        case .sftp:
            let session = sshSession!

            var isCancelled = false

            isolationQueue.async(flags: .barrier) {
                if isCancelled {
                    return
                }

                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion?(error)
                    }
                    return
                }

                let result: Bool

                result = session.sftp.removeFile(atPath: path)

                let error = (result ? nil : self.error)

                if !isCancelled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        completion?(error)
                    }
                }

                self.sftpDisconnect()
            }

            return CancellableRequest {
                _ in
                isCancelled = true
            }
        case .ftp:
            let request = WRRequestDelete()

            configureWRRequest(request: request)
            request.path = path

            request.completion = {
                success in
                request.completion = nil
                if success {
                    completion?(nil)
                } else {
                    completion?(request.error?.nsError)
                }
                return
            }

            request.start()

            return CancellableRequest {
                _ in
                request.destroy()
            }
        }
    }

    @discardableResult internal func downloadFileAsync(path: String, completion: ((URL?, Error?) -> ())? = nil, progress: ((Float) -> ())? = nil) -> CancellableRequest! {
        switch proto {
        case .sftp:
            let session = sshSession!

            var running = true

            isolationQueue.async(flags: .barrier) {

                if !running {
                    return
                }

                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion?(nil, error)
                    }
                    return
                }
                
                
                let fileUrl = FileManager.default.temporaryFileURL()
                let outputStream = OutputStream(url: fileUrl, append: false)!
                
                let result = session.sftp.contents(atPath: path, to: outputStream, progress: { (downloaded, total) -> Bool in
                    
                    DispatchQueue.main.async {
                        progress?(Float(downloaded) / Float(total))
                    }

                    return running
                })

                self.sftpDisconnect()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let error = (result ? nil : session.lastError)

                    if !running {
                        return
                    }

                    completion?(fileUrl, error)
                }
            }

            return CancellableRequest {
                _ in
                running = false
            }

        case .ftp:

            let downloadRequest = WRRequestDownload()
            let fileInfoRequest = WRRequestListDirectory()

            func startDownloadTask(detectedFileSize: Float? = nil) {

                configureWRRequest(request: downloadRequest)
                downloadRequest.path = path

                downloadRequest.completion = {
                    _ in
                    downloadRequest.completion = nil
                    completion?(downloadRequest.receivedFile, downloadRequest.error?.nsError)
                }
                if let fileSize = detectedFileSize {
                    let fileSize = Float(fileSize)
                    downloadRequest.progress = {
                        bytesRead in

                        progress!(Float(bytesRead) / fileSize)
                    }
                }

                DispatchQueue.main.async {
                    downloadRequest.start()
                }
            }

            if progress != nil {
                configureWRRequest(request: fileInfoRequest)

                let url = URL(fileURLWithPath: path)

                fileInfoRequest.path = url.deletingLastPathComponent().path

                fileInfoRequest.completion = {
                    success in

                    fileInfoRequest.completion = nil

                    if success {

                        let properlyEncodedName = self.encodeFTPFileName(filename: url.lastPathComponent)

                        var fileSize: UInt32?

                        for file in fileInfoRequest.filesInfo {
                            guard let file = file as? [String: Any] else {
                                continue
                            }
                            guard let name = file["kCFFTPResourceName"] as? String else {
                                continue
                            }
                            guard let type = file["kCFFTPResourceType"] as? Int32 else {
                                continue
                            }
                            guard let size = file["kCFFTPResourceSize"] as? UInt32 else {
                                continue
                            }
                            guard type == DT_REG || type == DT_LNK else {
                                continue
                            }
                            guard name == properlyEncodedName else {
                                continue
                            }

                            fileSize = size
                        }

                        if fileSize == nil {

                            let error = WRRequestError()

                            error.errorCode = WRErrorCodes(rawValue: 550)! //kWRFTPServerFileNotAvailable

                            completion?(nil, error.nsError)
                        } else {
                            startDownloadTask(detectedFileSize: Float(fileSize!))
                        }

                    } else {
                        completion?(nil, fileInfoRequest.error.nsError)
                    }
                }


                DispatchQueue.main.async {
                    fileInfoRequest.start()
                }

            } else {
                startDownloadTask()
            }

            return CancellableRequest {
                _ in
                downloadRequest.destroy()
                fileInfoRequest.destroy()
            }
        }
    }

    @discardableResult internal func uploadFileAsync(path: String, data: Data, completion: ((Error?) -> ())? = nil, progress: ((Float) -> ())? = nil) -> CancellableRequest! {

        let inputStream = InputStream(data: data)
        let size = Float(data.count)

        return uploadFileAsync(path: path, input: inputStream, completion: completion, progress: { (bytesWritten) in
            progress?(Float(bytesWritten) / size)
        })
    }

    @discardableResult internal func uploadFileAsync(path: String, input: InputStream, completion: ((Error?) -> ())? = nil, progress: ((UInt) -> ())? = nil) -> CancellableRequest! {
        switch proto {
        case .sftp:

            let session = sshSession!

            var running = true

            isolationQueue.async(flags: .barrier) {
                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion?(error)
                    }

                    return
                }

                let isSuccess = session.sftp.write(input, toFileAtPath: path, progress: { bytesWritten -> Bool in

                    DispatchQueue.main.async {
                        progress?(bytesWritten)
                    }

                    return running
                })

                if running {
                    DispatchQueue.main.async {
                        if !isSuccess {
                            completion?(self.error)
                        } else {
                            completion?(nil)
                        }
                    }
                }

                self.sftpDisconnect()
            }

            return CancellableRequest {
                _ in
                running = false
            }

        case .ftp:

            let request = WRRequestUpload()

            configureWRRequest(request: request)
            request.path = path

            request.dataStream = input

            request.completion = {
                success in
                request.completion = nil
                if success {
                    completion?(nil)
                } else {
                    completion?(request.error?.nsError)
                }
            }

            DispatchQueue.main.async {
                request.start()
            }

            return CancellableRequest {
                _ in
                request.destroy()
            }
        }
    }

    internal func createSymlink(path: String, target: String, completion: ((Error?) -> ())? = nil) {
        guard proto == .sftp else {
            return
        }

        let session = sshSession!

        isolationQueue.async(flags: .barrier) {

            if let error = self.sftpConnect() {
                if completion != nil {
                    DispatchQueue.main.async {
                        completion!(error)
                    }
                }
                return
            }


            let success = session.sftp.createSymbolicLink(atPath: path, withDestinationPath: target)

            if completion != nil {
                DispatchQueue.main.async {
                    completion!(success ? nil : self.error)
                }
            }

            self.sftpDisconnect()
        }
    }

    private func parseSFTPFile(file: NMSFTPFile, parentURL url: URL) -> FSNode {
        let permissions = file.permissions!

        let type = permissions[permissions.startIndex]
        let modificationDate = file.modificationDate

        let fileUrl = url.appendingPathComponent(file.filename)

        let isShortcut = type == "l" || type == "s"
        let isDirectory = type == "d"

        if isDirectory {
            let folder = FTPFolder(url: fileUrl, sourceType: sourceType)
            folder.modificationDate = modificationDate

            return folder
        } else if isShortcut {
            let symlink = FTPShortcut(url: fileUrl)
            return symlink
        } else {
            let file = FTPFile(url: fileUrl, size: file.fileSize!.int64Value, sourceType: sourceType)
            file.modificationDate = modificationDate
            return file
        }
    }

    private func parseFTPFile(file: [String: Any], parentURL url: URL) -> FSNode? {
        guard let type = file["kCFFTPResourceType"] as? Int32 else {
            return nil
        }
        guard let name = file["kCFFTPResourceName"] as? String else {
            return nil
        }
        guard let date = file["kCFFTPResourceModDate"] as? Date else {
            return nil
        }
        guard name != "." && name != ".." else {
            return nil
        }

        guard let decodedName = decodeFTPFileName(filename: name) else {
            return nil
        }

        let fileUrl = url.appendingPathComponent(decodedName)

        if type == DT_REG {
            guard let size = file["kCFFTPResourceSize"] as? Int64 else {
                return nil
            }

            let ftpFile = FTPFile(url: fileUrl, size: size, sourceType: sourceType)
            ftpFile.modificationDate = date
            return ftpFile
        } else if type == DT_DIR {
            let folder = FTPFolder(url: fileUrl, sourceType: sourceType)
            folder.modificationDate = date
            return folder
        } else {
            return nil
        }
    }

    /// Returns information about a file located on the specified path.
    private func fetchFileInfo(path: String) -> (file: FSNode?, error: Error?) {

        func getNoFileError() -> Error {
            let error = WRRequestError()

            error.errorCode = WRErrorCodes(rawValue: 550)! // kWRFTPServerFileNotAvailable

            return error.nsError
        }

        let url = URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!

        switch proto {
        case .ftp:

            let request = WRRequestListDirectory()

            configureWRRequest(request: request)

            request.path = url.deletingLastPathComponent().path

            if runWRRequestSync(request: request) {

                let properlyEncodedName = encodeFTPFileName(filename: url.lastPathComponent)

                var fetchedFile: [String: Any]? = nil

                for file in request.filesInfo {
                    guard let file = file as? [String: Any] else {
                        continue
                    }
                    guard let name = file["kCFFTPResourceName"] as? String else {
                        continue
                    }
                    guard name == properlyEncodedName else {
                        continue
                    }

                    fetchedFile = file
                }

                if fetchedFile == nil {
                    return (file: nil, error: getNoFileError())
                } else {
                    guard let file = parseFTPFile(file: fetchedFile!, parentURL: url.deletingLastPathComponent()) else {
                        return (file: nil, error: nil)
                    }

                    return (file: file, error: nil)
                }

            } else {
                return (file: nil, error: request.error.nsError)
            }

        case .sftp:

            let session = sshSession!

            guard let file = session.sftp.infoForFile(atPath: path) else {
                return (file: nil, error: error)
            }

            let fsNode = parseSFTPFile(file: file, parentURL: url.deletingLastPathComponent())

            return (file: fsNode, error: nil)
        }
    }

    internal func infoForFileAt(path: String, completion: @escaping (FSNode?, Error?) -> ()) {

        switch proto {
        case .sftp:
            isolationQueue.async(flags: .barrier) {
                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                    return
                }

                let result = self.fetchFileInfo(path: path)

                DispatchQueue.main.async {
                    completion(result.file, result.error)
                }

                self.sftpDisconnect()
            }
        case .ftp:

            let result = fetchFileInfo(path: path)

            completion(result.file, result.error)

            break
        }
    }

    internal func getSymlinkTarget(path: String, completion: @escaping (String?, Error?) -> ()) {
        guard proto == .sftp else {
            return
        }

        let session = sshSession!

        isolationQueue.async(flags: .barrier) {

            if let error = self.sftpConnect() {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            let result = session.sftp.realpath(path)

            DispatchQueue.main.async {
                completion(result, result == nil ? self.error : nil)
            }

            self.sftpDisconnect()
        }
    }


    private func sortFiles(files: [FSNode]) -> [FSNode] {
        switch userPreferences.sortingType {

        case .byLastEditingDate:
            return files
        case .byCreationDate:
            return files
        case .byName:
            return files.sorted { (a, b) -> Bool in
                a.name < b.name
            }
        case .byType:

            return files.sorted { (a, b) -> Bool in
                let p1 = a is FTPFile.Folder ? 1 : a is FTPFile.Shortcut ? 2 : 3
                let p2 = b is FTPFile.Folder ? 1 : b is FTPFile.Shortcut ? 2 : 3

                if (p1 != p2) {
                    return p1 < p2
                }

                return a.url.pathExtension < b.url.pathExtension
            }
        case .none:
            return files
        }

    }

    @discardableResult internal func listDirectoryAsync(path: String, sort: Bool = false, completion: @escaping ([FSNode]?, Error?) -> ()) -> CancellableRequest! {
        switch proto {
        case .sftp:
            let session = sshSession!

            let isCancelled = false

            isolationQueue.async(flags: .barrier) {

                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                    return
                }

                if let result = session.sftp.contentsOfDirectory(atPath: path) {
                    var files = [FSNode]()
                    let requestURL = URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!

                    for file in result {
                        files.append(self.parseSFTPFile(file: file, parentURL: requestURL))
                    }

                    if isCancelled {
                        return
                    }

                    if (sort) {
                        DispatchQueue(label: "jakmobius.easyhtml.sortingqueue").async {
                            files = self.sortFiles(files: files)

                            DispatchQueue.main.async {
                                completion(files, nil)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(files, nil)
                        }
                    }

                } else if !isCancelled {

                    DispatchQueue.main.async {
                        completion(nil, session.lastError)
                    }
                }

                self.sftpDisconnect()
            }

            return nil

        case .ftp:

            let request = WRRequestListDirectory()

            configureWRRequest(request: request)
            request.path = path

            request.completion = { success in
                request.completion = nil
                if success {

                    let url = URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!

                    var files = [FSNode]()
                    for file in request.filesInfo {
                        if let info = file as? Dictionary<String, Any> {
                            guard let fsNode = self.parseFTPFile(file: info, parentURL: url) else {
                                continue
                            }

                            files.append(fsNode)
                        }
                    }
                    completion(files, nil)
                } else {
                    completion(nil, request.error?.nsError)
                }
            }

            DispatchQueue.main.async {
                request.start()
            }

            return CancellableRequest { _ in
                request.destroy()
            }
        }
    }

    internal func copyFileAsync(file: FTPFile, to destination: String, completion: ((Error?) -> ())? = nil, progress: ((Float) -> ())? = nil) -> CancellableRequest! {
        switch proto {
        case .sftp:

            let session = sshSession!
            var running = true

            isolationQueue.async(flags: .barrier) {
                if let error = self.sftpConnect() {
                    DispatchQueue.main.async {
                        completion?(error)
                    }

                    return
                }

                var total: Float = -1

                let success = session.sftp.copyContents(ofPath: file.url.path, toFileAtPath: destination, progress: {
                    completed, _total in

                    if total <= 0 {
                        total = Float(_total)
                    }

                    let prog = Float(completed) / total

                    DispatchQueue.main.async {
                        progress?(prog)
                    }

                    return running
                })

                DispatchQueue.main.async {
                    if success {
                        completion?(nil)
                    } else {
                        completion?(self.error)
                    }
                }

                self.sftpDisconnect()
            }

            return CancellableRequest {
                _ in
                running = false
            }
        case .ftp:

            // FTP does not support file copying, so the fallback is to
            // download file and then upload it with different name.

            let downloadRequest = WRRequestDownload()

            var currentRequest: WRRequest = downloadRequest

            configureWRRequest(request: downloadRequest)
            downloadRequest.path = file.url.path

            downloadRequest.completion = {
                success in
                downloadRequest.completion = nil
                if success {
                    uploadFile()
                } else {
                    completion?(downloadRequest.error?.nsError)
                }
            }

            func uploadFile() {

                progress?(0.5)

                let uploadRequest = WRRequestUpload()
                uploadRequest.dataStream = InputStream(fileAtPath: downloadRequest.receivedFile.path)
                currentRequest = uploadRequest

                configureWRRequest(request: uploadRequest)
                uploadRequest.path = destination

                uploadRequest.completion = {
                    success in
                    uploadRequest.completion = nil
                    try? FileManager.default.removeItem(at: downloadRequest.receivedFile)
                    if success {
                        completion?(nil)
                    } else {
                        completion?(uploadRequest.error?.nsError)
                    }
                }

                uploadRequest.start()
            }

            downloadRequest.start()

            return CancellableRequest {
                _ in
                currentRequest.destroy()
            }
        }
    }

    func copy(with zone: NSZone? = nil) -> Any {

        guard case let .ftp(server) = sourceType else {
            fatalError()
        }

        return FTPUniversalSession(server: server)
    }
    
    func destroy() {
        switch proto {
        case .sftp:
            let session = sshSession
            guard (session?.isConnected)! else {
                return
            }
            isolationQueue.async(flags: .barrier) {
                session!.disconnect()
            }
        case .ftp:
            // Do nothing
            break;
        }
    }

    deinit {
        destroy()
    }
}
