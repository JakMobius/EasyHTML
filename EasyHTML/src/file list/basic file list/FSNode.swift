//
//  FSNode.swift
//  EasyHTML
//
//  Created by Артем on 06.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation
import MobileCoreServices

internal class FSNodeWrapper: Decodable {
    var fsNode: FSNode
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FSNode.CodingKeys.self)
        let family = try container.decode(String.self, forKey: .family)
        let cls = NSClassFromString(family) as! (FSNode.Type)
        fsNode = try cls.init(from: decoder)
    }
}

var kUTTypeFile = "EasyHTMLFile"

internal class FSNode: NSObject, NSItemProviderWriting, NSItemProviderReading, Encodable, Decodable
{
    
    struct FSNodeDragDropNotLocalFileError: LocalizedError {
        var localizedDescription: String {
            return localize("dndnotlocalfile", .files)
        }
    }
    
    struct FSNodeDragDropError: LocalizedError {
        var localizedDescription: String {
            return localize("unknownerror")
        }
    }
    
    fileprivate enum CodingKeys: String, CodingKey {
        case url
        case sourceType
        case family
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(url, forKey: .url)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encode(NSStringFromClass(type(of: self)), forKey: .family)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let url = try container.decode(URL.self, forKey: .url)
        let sourceType = try container.decode(FileSourceType.self, forKey: .sourceType)
        
        _url = url
        _title = _url.lastPathComponent
        self.sourceType = sourceType
    }
    
    class var readableTypeIdentifiersForItemProvider: [String] {
        return [
            kUTTypeFile,
            (kUTTypeData as String)
        ]
    }
    
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        if typeIdentifier == kUTTypeFile {
            let decoder = JSONDecoder()
            
            let wrapper = try decoder.decode(FSNodeWrapper.self, from: data)
            
            return wrapper.fsNode as! Self
        } else if typeIdentifier == kUTTypeData as String {
            
            let tempDirPath = NSTemporaryDirectory()
            
            var fileDir: String
            repeat {
                fileDir = tempDirPath + UUID().uuidString
            } while(fileOrFolderExist(name: fileDir))
            
            let url = URL(fileURLWithPath: fileDir)
            
            try data.write(to: url)
            
            return FSNode(url: url) as! Self
        }
        throw FSNodeDragDropError()
    }
    
    class var writableTypeIdentifiersForItemProvider: [String] {
        return [
            kUTTypeFile,
            (kUTTypeData as String)
        ]
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        
        if typeIdentifier == kUTTypeFile {
            do {
                let data = try JSONEncoder().encode(self)
                completionHandler(data, nil)
            } catch {
                completionHandler(nil, error)
            }
        } else if typeIdentifier == kUTTypeData as String {
            if sourceType != .local {
                completionHandler(nil, FSNodeDragDropNotLocalFileError())
                return nil
            }
            
            let data = try? Data(contentsOf: self.url)
            
            completionHandler(data, nil)
        }
        
        return nil
    }
    
    
    internal override func isEqual(_ object: Any?) -> Bool {
        if let file = object as? FSNode {
            return file.sourceType == sourceType && file.url == url
        }
        return false
    }
    
    internal enum SavingState {
        case saved, saving, error(backup: FileBackup?);
        
        internal struct FileBackup {
            internal var data: Data
            internal var file: FSNode
            internal var ioManager: Editor.IOManager
            
            internal func tryToRestore() {
                ioManager.saveFileAt(url: file.url, data: data, completion: {
                    error in
                    
                    let state: SavingState = (error == nil) ? .saved : .error(backup: self)
                    
                    self.file.setSavingState(state: state)
                    
                    FileBrowser.fileMetadataChanged(file: self.file)
                })
            }
        }
    }
    
    internal class Folder: FSNode {
        
        override class var readableTypeIdentifiersForItemProvider: [String] {
            return [
                kUTTypeFile
            ]
        }
        
        override class var writableTypeIdentifiersForItemProvider: [String] {
            return [
                kUTTypeFile
            ]
        }
        
        internal var countOfFilesInside: Int {
            get {
                let fullPath = _url.path
                
                return (try? FileManager.default.contentsOfDirectory(atPath: fullPath))?.count ?? 0
            }
        }
    }
    
    internal class Shortcut: FSNode {
        
        internal var destinationURL: URL?
    }
    
    internal class File: FSNode {
        internal var size: Int64 {
            get {
                let fullPath = _url.path
                return Int64(getFileAttrubutes(fileName: fullPath).fileSize())
            }
        }
        internal var localizedFileSize: String {
            get {
                return getLocalizedFileSize(bytes: size)
            }
        }
    }
    
    // MARK: File info
    
    internal var sourceType: FileSourceType = .unknown
    internal var name: String {
        get {
            return _title
        }
        set {
            _title = newValue
            _url = _url.deletingLastPathComponent().appendingPathComponent(_title)
            cachedMetadata = nil
        }
    }
    private var _title: String
    private var _url: URL
    
    internal final var url: URL {
        get {
            return _url
        }
        set {
            _url = newValue
            name = newValue.lastPathComponent
            cachedMetadata = nil
        }
    }
    
    // MARK: File metadata management
    
    private func readMetadata() {
        self.cachedMetadata = TemproraryFileMetadataManager.getFileMetadata(file: self)
    }
    
    internal var cachedMetadata: NSMutableDictionary? = nil
    
    internal var hasMetadata: Bool {
        get {
            readMetadata()
            
            return cachedMetadata != nil
        }
    }
    
    internal func createMetadata() -> NSMutableDictionary {
        let metadata: NSMutableDictionary = .init()
        TemproraryFileMetadataManager.setFileMetadata(file: self, metadata: metadata)
        self.cachedMetadata = metadata
        return metadata
    }
    
    internal func getSavingState() -> SavingState {
        
        readMetadata()
        
        if let state = self.cachedMetadata?["savingState"] as? SavingState {
            return state
        } else {
            return .saved
        }
    }
    
    internal func setSavingState(state: SavingState) {
        
        if case .saved = state {
            
            if !hasMetadata {
                return
            } else {
                self.cachedMetadata!.removeObject(forKey: "savingState")
                TemproraryFileMetadataManager.clearJunkMetadataForFile(file: self)
            }
            
        } else {
            var metadata: NSMutableDictionary
            
            if hasMetadata {
                metadata = self.cachedMetadata!
            } else {
                metadata = self.createMetadata()
            }
            
            metadata["savingState"] = state
        }
    }
    
    /**
     Запоминает позицию прокручивания файла, если она больше 50 по одной из координат
     - argument point: Позиция прокручивания файла
     */
    
    internal func setScrollPositionPoint(point: CGPoint?) {
        
        var metadata: NSMutableDictionary
        
        if !hasMetadata {
            metadata = createMetadata()
        } else {
            metadata = self.cachedMetadata!
        }
        
        if point == nil || (point!.x < 50 && point!.y < 50) {
            metadata.removeObject(forKey: "scrollPosition")
            return
        }
        
        metadata["scrollPosition"] = point
    }
    
    /**
     Возвращает позицию прокручивания, если она была записана ранее методом `setScrollPositionPoint`
     - returns: Позицию прокручивания для этого файла, или `nil` если её не записано в метаданных файла
     */
    
    internal func getScrollPositionPoint() -> CGPoint? {
        readMetadata()
        
        if let point = self.cachedMetadata?["scrollPosition"] as? CGPoint {
            return point
        } else {
            return nil
        }
    }
    
    // MARK: Initializers
    
    init(url: URL) {
        _url = url
        _title = _url.lastPathComponent
    }
    
    internal init(url: URL, sourceType: FileSourceType) {
        _url = url
        _title = _url.lastPathComponent
        self.sourceType = sourceType
    }
    
    internal static func getLocalFile(globalURL: URL) -> FSNode? {
        var isDir: ObjCBool = false
        
        if(!FileManager.default.fileExists(atPath: globalURL.path, isDirectory: &isDir)) {
            return nil
        }
        
        if isDir.boolValue {
            return Folder(url: globalURL, sourceType: .local)
        } else {
            return File(url: globalURL, sourceType: .local)
        }
    }
    
    internal static func getLocalFile(url: URL) -> FSNode? {
        var isDir: ObjCBool = false
        
        let fullPath = applicationPath + FileBrowser.filesDir + url.path
        
        if(!FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)) {
            return nil
        }
        
        let fullURL = URL(fileURLWithPath: fullPath)
        
        if isDir.boolValue {
            return Folder(url: fullURL, sourceType: .local)
        } else {
            return File(url: fullURL, sourceType: .local)
        }
    }
    
    internal override var description: String {
        get {
            return "\(NSStringFromClass(type(of: self))) \(self.sourceType) \(self.url)"
        }
    }
}
