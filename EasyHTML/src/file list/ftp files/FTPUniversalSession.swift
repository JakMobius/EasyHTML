//
//  FTPUniversalSession.swift
//  EasyHTML
//
//  Created by Артем on 04/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation
import NMSSH

/**
 Универсальная (для ´ftp´, ´ftps´ и ´sftp´) потокобезопасная сессия для управления удаленными файловыми системами через
 указанные выше протоколы.
 */

internal class FTPUniversalSession: NSObject, NSCopying {
    
    /*
     Нам не нужно поле ´host´ когда мы используем соединение по SFTP, поэтому оно поставлено в optional
     */
    
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
            return NSError(domain: "libssh2", code: Int(LIBSSH2_ERROR_NONE), userInfo: [NSLocalizedDescriptionKey : "No active session"])
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
            if let error = session.connect() {
                return error
            }
            
            session.authenticate(byPassword: password)
            
            if !session.isAuthorized {
                return error
            }
        }
        return nil
    }
    
    private var sftpConnectionTimeout: TimeInterval = 60 // 1 минута
    private var sftpDisconnectionDate: Date! = nil
    private var sftpSession: NMSFTP! = nil
    
    private func sftpConnect() -> Error! {
        
        if let session = sftpSession {
            if(sftpDisconnectionDate != nil){
                if(Date().timeIntervalSince(sftpDisconnectionDate) > sftpConnectionTimeout) {
                    sftpSession = nil
                }
            }
            
            if(session.isConnected) {
                return nil
            }
            
            // Попробуем переподключиться...
        }
        
        if let session = sshSession {
            if !session.isConnected {
                if let error = sshSession.connect() {
                    return error
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
                        
                        // Видать, сервер не поддерживает SFTP. Что поделать, бывает и такое.
                        // Нет времени до дедлайна чтобы делать локализованные версии ошибок.
                        // Оставляем так. Возможно, потом доделаю на досуге. #TODO
                        
                        return NSError(domain: "libssh2", code: -9283, userInfo: [NSLocalizedDescriptionKey : "Connection succeeded, but failed to init SFTP session on this server"])
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
        self.password = server.password
        self.username = server.username
        self.proto = server.connectionType
        self.fullhost = server.host + ":\(server.port)"
        self.hostname = server.host
        self.port = server.port
        self.passive = server.ftpConnectionIsPassive
        self.sourceType = .ftp(server: server)
        
        self.isolationQueue = DispatchQueue(label: "easyhtml.ftpqueue-\(UUID().uuidString)", attributes: .concurrent)
        
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
                    completion?(request.error?.nserror)
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
    
    private func getAllFolderResources(path: String, progress: @escaping ((UInt64) -> (Bool)), prefix: String = "") -> (error: Error?, result: [Resource]?) {
        
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
            
            // Подразумевается, что во время вызова этой функции
            // сессия уже создана и выполняется синхронно с isolationTask
            
            let session = sshSession!
            var result = [Resource]()
            if let contents = session.sftp.contentsOfDirectory(atPath: prefix + path) as? [NMSFTPFile] {
                
                var counted: UInt64 = 0
                
                for file in contents {
                    let permissions = file.permissions!
                    let path = path + file.filename
                    
                    if permissions.first == "d" {
                        
                        let subdirectory = getAllFolderResources(path: path, progress: { subcounted in
                            return progress(counted + subcounted)
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
                        result.append(.file(path: path, size: file.fileSize.int64Value))
                    }
                    
                    counted += 1
                }
                
                result.append(.folder(path: path))
                
                return (error: nil, result: result)
                
            } else if let error = self.error {
                let nserror = error as NSError
                var userInfo = nserror.userInfo
                
                let localizedDescription = (userInfo[NSLocalizedDescriptionKey] as? String ?? "Unknown error")
                
                if path != "/" {
                    userInfo[NSLocalizedDescriptionKey] = localizedDescription + " at path \(path)"
                } else {
                    userInfo[NSLocalizedDescriptionKey] = localizedDescription
                }
                
                let newError = NSError(domain: nserror.domain, code: nserror.code, userInfo: userInfo)
                return (error: newError, result: nil)
            }
            
            return (error: nil, result: nil)
            
        case .ftp:
            
            let request = WRRequestListDirectory()
            
            configureWRRequest(request: request)
            
            request.path = prefix + path
            
            // Используем Semaphore, чтобы подождать завершения чтения папки
            
            var result: [Resource]! = nil
            var error: Error! = nil
            var counted: UInt64 = 0
            
            let success = runWRRequestSync(request: request)
            
            if success {
                result = []
                
                for info in request.filesInfo {
                    if let info = info as? Dictionary<String, Any> {
                        guard let type = info["kCFFTPResourceType"] as? Int32 else { continue }
                        guard let name = info["kCFFTPResourceName"] as? String else { continue }
                        guard name != "." && name != ".." else { continue }
                        
                        guard let decodedName = decodeFTPFileName(filename: name) else { continue }
                        
                        if type == DT_DIR {
                            
                            var subdirectory: (error: Error?, result: [Resource]?)
                            
                            subdirectory = self.getAllFolderResources(path: path + decodedName, progress: { subcounted in
                                progress(counted + subcounted)
                            }, prefix: prefix)
                            if let suberror = subdirectory.error {
                                result = nil
                                return (error: suberror, result: nil)
                            }
                            
                            guard let subresult = subdirectory.result else {
                                return (error: nil, result: nil)
                            }
                            
                            result.append(contentsOf: subresult)
                            
                            counted += UInt64(subresult.count)
                            
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
                error = request.error.nserror
            }
            
            if let error = error {
                let nserror = error as NSError
                var userInfo = nserror.userInfo
                
                let localizedDescription = (userInfo[NSLocalizedDescriptionKey] as? String ?? "Unknown error")
                
                if path != "/" {
                    userInfo[NSLocalizedDescriptionKey] = localizedDescription + " at path \(path)"
                } else {
                    userInfo[NSLocalizedDescriptionKey] = localizedDescription
                }
                
                let newError = NSError(domain: nserror.domain, code: nserror.code, userInfo: userInfo)
                return (error: newError, result: nil)
            }
            
            return (result: result, error: nil)
        }
    }
    
    internal enum FolderDeletionState {
        case countingFiles(counted: UInt64), deletingFiles(deleted: UInt64, total: UInt64)
    }
    
    internal enum FolderCopyingState {
        case countingFiles(counted: UInt64), copyingFiles(copied: UInt64, total: UInt64)
    }
    
    /**
     Запускает указанный `WRRequest` синхронно с текущим потоком, используя `DispatchSemaphore`
     - returns: true, если запрос был завершен успешно, иначе - false
     */
    
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
    
    /**
     Конфигурирует `WRRequest`: Устанавливает значения полей хоста, логина и пароля
     */
    
    private func configureWRRequest(request: WRRequest) {
        request.username = self.username
        request.password = self.password
        request.hostname = self.fullhost
        request.passive = self.passive
    }
    
    struct FTPError: LocalizedError {
        let filename: String
        let error: Error
        
        var localizedDescription: String {
            return localize("failedtocopyfile")
                .replacingOccurrences(of: "#", with: filename)
                .appending("\n").appending(error.localizedDescription)
        }
        
        var errorDescription: String? {
            return localizedDescription
        }
    }
    
    func calculateFolderSizeAsync(folder: FTPFolder, completion: ((Int64?, Error?) -> ())?) -> CancellableRequest {
        
        var running = true
        
        func evaluate() {
            
            let result = self.getAllFolderResources(path: "", progress: { (count) in
                return running
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
    
    typealias ErrorHandlerCallback = ((Error, @escaping (RelocationErrorRestoreType) -> ()) -> ())? // Ужас, да?
    
    private func downloadFolderFTP(folder: FTPFolder, to path: String, errorHandler: ErrorHandlerCallback, completion: ((Error?) -> ())?, progress: ((Float) -> ())? = nil) -> CancellableRequest! {
        
        var running = true
        var currentRequest: WRRequest! = nil
        let sourcePath = folder.url.path
        guard let url = URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else { return nil }
        
        isolationQueue.async {
            let result = self.getAllFolderResources(path: "", progress: { (count) in
                return running
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
            
            // Инвертируем список файлов, чтобы сначала создавать папки,
            // а затем копировать в них файлы.
            
            guard var resources = result.result?.reversed() else {
                return
            }
            
            let totalCount = Float(resources.count)
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
                    case .file(let filepath, _):
                        
                        let fileurl = url.appendingPathComponent(filepath)
                        let sourceurl = folder.url.appendingPathComponent(filepath)
                        
                        if(ignore != nil) {
                            if(filepath.hasPrefix(ignore!)) {
                                return true
                            } else {
                                ignore = nil
                            }
                        }
                        
                        let request = WRRequestDownload()
                        
                        self.configureWRRequest(request: request)
                        
                        request.receivedFile = fileurl
                        request.path = sourceurl.path
                        
                        currentRequest = request
                        
                        let success = self.runWRRequestSync(request: request)
                        
                        currentRequest = nil
                        
                        if !success {
                            let error = FTPError(filename: sourceurl.lastPathComponent, error: request.error.nserror!)
                            errorOccurred(error: error)
                            
                            return false
                        }
                        
                        copied += 1
                        
                    case .folder(let folderpath):
                        
                        let folderurl = url.appendingPathComponent(folderpath)
                        let sourceurl = folder.url.appendingPathComponent(folderpath)
                        
                        if(ignore != nil) {
                            if(folderpath.hasPrefix(ignore!)) {
                                return true
                            } else {
                                ignore = nil
                            }
                        }
                        
                        do {
                            try FileManager.default.createDirectory(at: folderurl, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                            let error = FTPError(filename: sourceurl.lastPathComponent, error: error)
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
                while nextRequest() {}
            }
            
            continueIteration()
        }
        
        return CancellableRequest() {
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
        
        isolationQueue.async(flags: .barrier) {
            
            if let error = self.sftpConnect() {
                DispatchQueue.main.async {
                    completion?(error)
                }
                return
            }
            
            let result = self.getAllFolderResources(path: "", progress: { _ in
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
            
            // Инвертируем список файлов, чтобы сначала создавать папки,
            // а затем копировать в них файлы.
            
            guard var resources = result.result?.reversed() else {
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
            
            // nextResource возвращает Bool - индикатор того,
            // следует ли продолжать итерировать по запросам
            // Если использовать рекурсивный метод, то очень
            // высока вероятность схватить StackOverflow, так
            // как все запросы происходят синхронно.
            
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
                                            if case let .folder(path) = resource
                                            {
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
                    case .file(let filepath, _):
                        
                        if ignore != nil {
                            if(filepath.hasPrefix(ignore!)) {
                                return true
                            } else {
                                ignore = nil
                            }
                        }
                        
                        let fileurl = url.appendingPathComponent(filepath)
                        
                        guard let _ = session.sftp.downloadFile(atPath: sourcePath + filepath, to: url.appendingPathComponent(filepath) , progress: {
                            _, _ in
                            return running
                        }) else {
                            
                            let error = FTPError(filename: fileurl.lastPathComponent, error: self.error!)
                            errorOccurred(error: error)
                            
                            return false
                        }
                        
                    case .folder(let folderpath):
                        
                        if ignore != nil {
                            if(folderpath.hasPrefix(ignore!)) {
                                return true
                            } else {
                                ignore = nil
                            }
                        }
                        
                        let folderurl = url.appendingPathComponent(folderpath)
                        
                        do {
                            // Пробуем
                            
                            try FileManager.default.createDirectory(at: folderurl, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                            // Не получилось
                            
                            let error = FTPError(filename: folderurl.lastPathComponent, error: error)
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
                while nextResource() {}
            }
            
            continueIteration()
        }
        
        return CancellableRequest() {
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
                
                // Инвертируем список файлов, чтобы сначала создавать папки,
                // а затем копировать в них файлы.
                
                guard let resources = result.result?.reversed() else {
                    return
                }
                let totalResults = UInt64(resources.count)
                var iterator = resources.makeIterator()
                var ignore: String? // Хранит в себе папку, которая в результате ошибки не была скопирована.
                
                var cloned: UInt64 = 0
                
                func nextRequest() -> Bool {
                    guard let resource = iterator.next() else {
                        
                        // Запросы закончились, копирование завершено успешно.
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
                        case .file(let filepath, _):
                            
                            if ignore != nil {
                                if(filepath.hasPrefix(ignore!)) {
                                    return true
                                } else {
                                    ignore = nil
                                }
                            }
                            
                            let success = session.sftp.copyContents(ofPath: sourcePath + filepath, toFileAtPath: path + filepath, progress: {
                                (written, total) -> Bool in
                                
                                return running
                            })
                            
                            if !success {
                                // Cпрашиваем юзера что делать в потоке main
                                // Текущий поток завершаем, возвращая маркер false
                                
                                let filename = URL(fileURLWithPath: sourcePath + filepath).lastPathComponent
                                let error = FTPError(filename: filename, error: self.error!)
                                
                                errorOccurred(error: error)
                                
                                return false
                            }
                            
                        case .folder(let folderpath):
                            
                            if ignore != nil {
                                if(folderpath.hasPrefix(ignore!)) {
                                    return true
                                } else {
                                    ignore = nil
                                }
                            }
                            
                            let success = session.sftp.createDirectory(atPath: path + folderpath)
                            
                            if !success {
                                // Cпрашиваем юзера что делать в потоке main
                                // Текущий поток завершаем, возвращая маркер false
                                
                                let filename = URL(fileURLWithPath: sourcePath + folderpath).lastPathComponent
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
                    while nextRequest() {}
                }
                
                continueIteration() // Поехали по запросам
            }
            
            return CancellableRequest() {
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
                
                let result = self.getAllFolderResources(path: "", progress: { counted -> (Bool) in
                    
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
                
                // Инвертируем список файлов, чтобы сначала создавать папки,
                // а затем копировать в них файлы.
                
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
                        
                        // Ставим progress-callback в начало цикла, чтобы
                        // уведомлять пользователя о начале процесса копирования
                        // сразу по завершении счета файлов
                        
                        DispatchQueue.main.async {
                            progress?(.copyingFiles(copied: cloned, total: totalResults))
                        }
                        
                        switch resource {
                        case .file(let filepath, _):
                            
                            if ignore != nil {
                                if filepath.hasPrefix(ignore!) {
                                    return true
                                } else {
                                    ignore = nil
                                }
                            }
                            
                            let downloadrequest = WRRequestDownload()
                            self.configureWRRequest(request: downloadrequest)
                            downloadrequest.path = sourcePath + filepath
                            currentRequest = downloadrequest
                            if !self.runWRRequestSync(request: downloadrequest) {
                                errorOccurred(error: downloadrequest.error.nserror)
                                
                                return false
                            }
                            
                            if !running {
                                self.sftpDisconnect()
                                return false
                            }
                            
                            let uploadrequest = WRRequestUpload()
                            self.configureWRRequest(request: uploadrequest)
                            uploadrequest.path = path + filepath
                            uploadrequest.dataStream = InputStream(fileAtPath: downloadrequest.receivedFile.path)
                            currentRequest = uploadrequest
                            
                            if !self.runWRRequestSync(request: uploadrequest) {
                                errorOccurred(error: uploadrequest.error.nserror)
                                
                                return false
                            }
                            
                            try? FileManager.default.removeItem(at: downloadrequest.receivedFile)
                        case .folder(let folderpath):
                            
                            if ignore != nil {
                                if folderpath.hasPrefix(ignore!) {
                                    return true
                                } else {
                                    ignore = nil
                                }
                            }
                            
                            let request = WRRequestCreateDirectory()
                            self.configureWRRequest(request: request)
                            request.path = path + folderpath
                            currentRequest = request
                            if !self.runWRRequestSync(request: request) {
                                errorOccurred(error: request.error.nserror)
                                
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
                    while nextRequest() {}
                }
                
                continueIteration()
                
                DispatchQueue.main.async {
                    progress?(.copyingFiles(copied: totalResults, total: totalResults))
                    completion?(nil)
                }
            }
            
            return CancellableRequest() {
                _ in
                running = false
                currentRequest?.destroy()
            }
        }
    }
    
    /**
     Перемещает файл на удаленном сервере.
     - note: SFTP поддерживает переименовывание директорий. FTP и FTPS поддерживает только переименовывание файлов.
     */
    
    @discardableResult internal func moveFileAsync(file: FSNode, to path: String, errorHandler: FTPUniversalSession.ErrorHandlerCallback, completion: ((Error?) -> ())? = nil) -> CancellableRequest! {
        return moveFileAsync(file: file.url.path, isDirectory: file is FTPFolder, to: path, errorHandler: errorHandler, completion: completion)
    }
    
    /**
     Перемещает файл на удаленном сервере.
     - note: SFTP поддерживает переименование директорий. FTP и FTPS поддерживает только переименовывание файлов.
     */
    
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
                
                self.configureWRRequest(request: request)
                self.configureWRRequest(request: uploadRequest)
                self.configureWRRequest(request: deleteRequest)
                
                request.path       = file
                uploadRequest.path = path
                deleteRequest.path = file
                
                request.completion = {
                    success in
                    request.completion = nil
                    if !success {
                        completion?(request.error.nserror)
                        return
                    }
                    uploadRequest.dataStream = InputStream(fileAtPath: request.receivedFile!.path)
                    uploadRequest.completion = {
                        success in
                        uploadRequest.completion = nil
                        if !success {
                            completion?(uploadRequest.error.nserror)
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
                
                return CancellableRequest() {
                    _ in
                    request.destroy()
                    uploadRequest.destroy()
                    deleteRequest.destroy()
                }
                
            } else {
                
                let folder = FTPFolder(
                    url: URL(string: file.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!,
                    sourceType: self.sourceType
                )
                
                self.copyFolderRecursivelyAsync(folder: folder, to: path, progress: nil, errorHandler: errorHandler, completion: {
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
    
    struct FTPFileDeletionFailed : LocalizedError {
        var wrerror: WRRequestError
        var fileName: String
        
        var errorDescription: String? {
            return localizedDescription
        }
        
        var localizedDescription: String {
            return localize("failedtodeletefile").replacingOccurrences(of: "#", with: fileName) + "\n" + String(wrerror.message ?? "")
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
                    
                    // Ставим progress-callback в начало цикла, чтобы
                    // уведомлять пользователя о начале процесса удаления
                    // сразу по завершении счета файлов
                    
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
            
            return CancellableRequest() {
                _ in
                running = false
            }
            
        case .ftp:
            var running = true
            
            isolationQueue.async {
                
                DispatchQueue.main.async {
                    progress?(.countingFiles(counted: 0))
                }
                
                let result = self.getAllFolderResources(path: folder.url.path, progress: { counted -> (Bool) in
                    
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
                    
                    // Ставим progress-callback в начало цикла, чтобы
                    // уведомлять пользователя о начале процесса удаления
                    // сразу по завершении счета файлов
                    
                    DispatchQueue.main.async {
                        progress?(.deletingFiles(deleted: deleted, total: totalResults))
                    }
                    
                    let request = WRRequestDelete()
                    
                    self.configureWRRequest(request: request)
                    
                    switch resource {
                    case .file(let filepath, _ ): request.path = filepath
                    case .folder(let folderpath): request.path = folderpath
                    }
                    
                    if !self.runWRRequestSync(request: request) {
                        DispatchQueue.main.async {
                            
                            if let error = request.error {
                                
                                let fileName = URL(fileURLWithPath: request.path).lastPathComponent
                                
                                let error = FTPFileDeletionFailed(wrerror: error, fileName: fileName)
                                
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
            
            return CancellableRequest() {
                _ in
                running = false
            }
        }
        
    }
    
    /**
     Удаляет указанный файл или ярлык с сервера.
     */
    
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
            
            return CancellableRequest() {
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
                    completion?(request.error?.nserror)
                }
                return
            }
            
            request.start()
            
            return CancellableRequest() {
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
                
                let url = session.sftp.downloadFile(atPath: path, progress: { (downloaded, total) -> Bool in
                    
                    DispatchQueue.main.async {
                        progress?(Float(downloaded) / Float(total))
                    }
                    
                    return running
                })
                
                self.sftpDisconnect()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let error = (url == nil ? session.lastError : nil)
                    
                    if !running {
                        return
                    }
                    
                    completion?(url, error)
                }
            }
            
            return CancellableRequest() {
                _ in
                running = false
            }
            
        case .ftp:
            
            let downloadRequest = WRRequestDownload()
            let fileInfoRequest = WRRequestListDirectory()
            
            func startDownloadTask(detectedFileSize: Float? = nil) {
                
                configureWRRequest(request: downloadRequest)
                downloadRequest.path     = path
                
                downloadRequest.completion = {
                    _ in
                    downloadRequest.completion = nil
                    completion?(downloadRequest.receivedFile, downloadRequest.error?.nserror)
                }
                if let fileSize = detectedFileSize {
                    let fileSize = Float(fileSize)
                    downloadRequest.progress = {
                        bytesReaden in
                        
                        progress!(Float(bytesReaden) / fileSize)
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
                            guard let file = file as? [String : Any] else { continue }
                            guard let name = file["kCFFTPResourceName"] as? String else { continue }
                            guard let type = file["kCFFTPResourceType"] as? Int32 else { continue }
                            guard let size = file["kCFFTPResourceSize"] as? UInt32 else { continue }
                            guard type == DT_REG || type == DT_LNK else { continue }
                            guard name == properlyEncodedName else { continue }
                            
                            fileSize = size
                        }
                        
                        if fileSize == nil {
                            
                            let error = WRRequestError()
                            
                            error.errorCode = WRErrorCodes(rawValue: 550)! //kWRFTPServerFileNotAvailable
                            
                            completion?(nil, error.nserror)
                        } else {
                            startDownloadTask(detectedFileSize: Float(fileSize!))
                        }
                        
                    } else {
                        completion?(nil, fileInfoRequest.error.nserror)
                    }
                }
                
                
                DispatchQueue.main.async {
                    fileInfoRequest.start()
                }
                
            } else {
                startDownloadTask()
            }
            
            return CancellableRequest() {
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
                    completion?(request.error?.nserror)
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
        guard proto == .sftp else { return }
        
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
        
        let fileurl = url.appendingPathComponent(file.filename)
        
        let isShortcut = type == "l" || type == "s"
        let isDirectory = type == "d"
        
        if isDirectory {
            let folder = FTPFolder(url: fileurl, sourceType: self.sourceType)
            folder.modificationDate = modificationDate
            
            return folder
        } else if isShortcut {
            let symlink = FTPShortcut(url: fileurl)
            return symlink
        } else {
            let file = FTPFile(url: fileurl, size: file.fileSize.int64Value, sourceType: self.sourceType)
            file.modificationDate = modificationDate
            return file
        }
    }
    
    private func parseFTPFile(file: [String : Any], parentURL url: URL) -> FSNode? {
        guard let type = file["kCFFTPResourceType"] as? Int32 else { return nil }
        guard let name = file["kCFFTPResourceName"] as? String else { return nil }
        guard let date = file["kCFFTPResourceModDate"] as? Date else { return nil }
        guard name != "." && name != ".." else { return nil }
        
        guard let decodedName = self.decodeFTPFileName(filename: name) else { return nil }
        
        let fileurl = url.appendingPathComponent(decodedName)
        
        if type == DT_REG {
            guard let size = file["kCFFTPResourceSize"] as? Int64 else { return nil }
            
            let ftpfile = FTPFile(url: fileurl, size: size, sourceType: self.sourceType)
            ftpfile.modificationDate = date
            return ftpfile
        } else if type == DT_DIR {
            let folder = FTPFolder(url: fileurl, sourceType: self.sourceType)
            folder.modificationDate = date
            return folder
        } else {
            return nil
        }
    }
    
    /**
     Возвращает информацию о файле, расположенном на указанном пути.
     
     - returns: file: полученный объект файла, или nil, если файл не найден.
     */
    
    private func fetchFileInfo(path: String) -> (file: FSNode?, error: Error?) {
        
        func getNoFileError() -> Error {
            let error = WRRequestError()
            
            error.errorCode = WRErrorCodes(rawValue: 550)! // kWRFTPServerFileNotAvailable
            
            return error.nserror
        }
        
        let url = URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        
        switch proto {
        case .ftp:
            
            let request = WRRequestListDirectory()
            
            configureWRRequest(request: request)
            
            request.path = url.deletingLastPathComponent().path
            
            if runWRRequestSync(request: request) {
                
                let properlyEncodedName = self.encodeFTPFileName(filename: url.lastPathComponent)
                
                var fetchedFile: [String : Any]? = nil
                
                for file in request.filesInfo {
                    guard let file = file as? [String : Any] else { continue }
                    guard let name = file["kCFFTPResourceName"] as? String else { continue }
                    guard name == properlyEncodedName else { continue }
                    
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
                return (file: nil, error: request.error.nserror)
            }
            
        case .sftp:
            
            let session = sshSession!
            
            guard let file = session.sftp.infoForFile(atPath: path) else { return (file: nil, error: self.error) }
            
            let fsnode = parseSFTPFile(file: file, parentURL: url.deletingLastPathComponent())
            
            return (file: fsnode, error: nil)
        }
    }
    
    internal func infoForFileAt(path: String, completion: @escaping (FSNode?, Error?) -> ()) {
        
        switch self.proto {
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
            
            let result = self.fetchFileInfo(path: path)
            
            completion(result.file, result.error)
            
            break
        }
    }
    
    internal func getSymlinkTarget(path: String, completion: @escaping (String?, Error?) -> ()) {
        guard proto == .sftp else { return }
        
        let session = sshSession!
        
        isolationQueue.async(flags: .barrier) {
            
            if let error = self.sftpConnect() {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            let result = session.sftp.readSymbolicLink(atPath: path)
            
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
                return a.name < b.name
            }
        case .byType:
            
            return files.sorted { (a, b) -> Bool in
                let p1 = a is FTPFile.Folder ? 1 : a is FTPFile.Shortcut ? 2 : 3
                let p2 = b is FTPFile.Folder ? 1 : b is FTPFile.Shortcut ? 2 : 3
                
                if(p1 != p2) {
                    return p1 < p2
                }
                
                return a.url.pathExtension < b.url.pathExtension
            }
        case .none:
            return files
        }
        
    }
    
    @discardableResult internal func listDirectoryAsync(path: String, sort: Bool = false, completion: @escaping (([FSNode]?, Error?) -> ())) -> CancellableRequest! {
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
                
                if let result = session.sftp.contentsOfDirectory(atPath: path) as? [NMSFTPFile] {
                    var files = [FSNode]()
                    let requestURL = URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
                    
                    for file in result {
                        files.append(self.parseSFTPFile(file: file, parentURL: requestURL))
                    }
                    
                    if isCancelled {
                        return
                    }
                    
                    if(sort) {
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
            
            self.configureWRRequest(request: request)
            request.path = path
            
            request.completion = { success in
                request.completion = nil
                if success {
                    
                    let url = URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
                    
                    var files = [FSNode]()
                    for file in request.filesInfo {
                        if let info = file as? Dictionary<String, Any> {
                            guard let fsnode = self.parseFTPFile(file: info, parentURL: url) else { continue }
                            
                            files.append(fsnode)
                        }
                    }
                    completion(files, nil)
                } else {
                    completion(nil, request.error?.nserror)
                }
            }
            
            DispatchQueue.main.async {
                request.start()
            }
            
            return CancellableRequest() { _ in
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
            
            return CancellableRequest() {
                _ in
                running = false
            }
        case .ftp:
            
            /*
             Раз уж FTP не поддерживает копирование, почему бы не реализовать свой
             собственный, ультра-извращенный механизм копирования файлов?
             Все потому, что надо использовать SFTP.
             */
            
            /*
             Начинаем представление.
             первым делом загружаем файл в оперативку.
             */
            
            let downloadRequest = WRRequestDownload()
            
            var currentRequest: WRRequest = downloadRequest
            
            configureWRRequest(request: downloadRequest)
            downloadRequest.path = file.url.path
            
            downloadRequest.completion = {
                success in
                downloadRequest.completion = nil
                if success {
                    
                    /*
                     Если всё огонь и мы загрузили файл на устройство, то продолжаем
                     уничтожать трафик пользователя.
                     Загружаем файл на сервер на новое место.
                     */
                    
                    continueThisNightmare()
                } else {
                    completion?(downloadRequest.error?.nserror)
                }
            }
            
            func continueThisNightmare() {
                
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
                        completion?(uploadRequest.error?.nserror)
                    }
                }
                
                uploadRequest.start()
            }
            
            downloadRequest.start()
            
            return CancellableRequest() {
                _ in
                currentRequest.destroy()
            }
        }
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        
        guard case let .ftp(server) = sourceType else { fatalError() }
        
        return FTPUniversalSession(server: server)
    }
    
    func destroy() {
        switch proto {
        case .sftp:
            let session = self.sshSession
            guard (session?.isConnected)! else { return }
            isolationQueue.async(flags: .barrier) {
                session!.disconnect()
            }
        case .ftp:
            // Do nothink
            break;
        }
    }
    
    deinit {
        destroy()
    }
}
