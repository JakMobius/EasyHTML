//
//  DropboxInputStream.swift
//  EasyHTML
//
//  Created by Артем on 02/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

/*
 Осторожно! Костыли!
 Если не сохранять "голый" InputStream внутри, то происходит ошибка
 "'NSInvalidArgumentException', reason: '*** -@название поля@ only defined for abstract class.  Define -[EasyHTML.DropboxInputStream @название поля@]!"
 Погуглив, я понял, что субклассируя InputStream нужно сохранять внутри его "абстрактную" копию. *Facepalm*
 */

class DropboxInputStream : InputStream {
    private var inputStream: InputStream;
    var maxStreamDataSize: UInt64 = 157286400 // 150 MB
    private(set) var bytesReaden: UInt64 = 0
    public let fileLength: Float
    
    var fractionCompleted: Float {
        return Float(bytesReaden) / fileLength
    }
    
    override var streamStatus: Stream.Status {
        return inputStream.streamStatus
    }
    
    override var streamError: Error? {
        return inputStream.streamError
    }
    
    override var delegate: StreamDelegate? {
        get {
            return inputStream.delegate
        }
        set {
            inputStream.delegate = newValue
        }
    }
    
    override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        inputStream.schedule(in: aRunLoop, forMode: mode)
    }
    
    override func open() {
        inputStream.open()
    }
    
    override func close() {
        inputStream.close()
    }
    
    override func property(forKey key: Stream.PropertyKey) -> Any? {
        return inputStream.property(forKey: key)
    }
    
    override var hasBytesAvailable: Bool {
        if inputStream.hasBytesAvailable {
            return bytesReaden < maxStreamDataSize
        }
        return false
    }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        
        var len = len
        
        if self.bytesReaden + UInt64(len) >= maxStreamDataSize {
            len = Int(maxStreamDataSize - bytesReaden)
        }
        
        if len == 0 {
            return 0
        }
        
        let readen = inputStream.read(buffer, maxLength: len)
        
        bytesReaden += UInt64(readen)
        
        return readen
    }
    
    override init?(url: URL) {
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        guard let filesize = attributes[.size] as? NSNumber else { return nil}
        
        self.fileLength = filesize.floatValue
        
        guard let inputStream = InputStream(url: url) else { return nil }
        self.inputStream = inputStream
        super.init(url: url)
    }
}
