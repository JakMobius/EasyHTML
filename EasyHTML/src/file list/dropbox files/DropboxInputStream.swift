//
//  DropboxInputStream.swift
//  EasyHTML
//
//  Created by Артем on 02/06/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

/*
 When subclassing InputStream one should keep its 'raw' version to fetch properties from it.
 Otherwise it will fail with the following message:
 "'NSInvalidArgumentException', reason: '*** -field_name only defined for abstract class.  Define -[EasyHTML.DropboxInputStream field_name]!"
 */

class DropboxInputStream: InputStream {
    private var inputStream: InputStream;
    var maxStreamDataSize: UInt64 = 157286400 // 150 MB
    private(set) var bytesRead: UInt64 = 0
    public let fileLength: Float

    var fractionCompleted: Float {
        Float(bytesRead) / fileLength
    }

    override var streamStatus: Stream.Status {
        inputStream.streamStatus
    }

    override var streamError: Error? {
        inputStream.streamError
    }

    override var delegate: StreamDelegate? {
        get {
            inputStream.delegate
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
        inputStream.property(forKey: key)
    }

    override var hasBytesAvailable: Bool {
        if inputStream.hasBytesAvailable {
            return bytesRead < maxStreamDataSize
        }
        return false
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {

        var len = len

        if bytesRead + UInt64(len) >= maxStreamDataSize {
            len = Int(maxStreamDataSize - bytesRead)
        }

        if len == 0 {
            return 0
        }

        let read = inputStream.read(buffer, maxLength: len)

        bytesRead += UInt64(read)

        return read
    }

    override init?(url: URL) {

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        guard let filesize = attributes[.size] as? NSNumber else {
            return nil
        }

        fileLength = filesize.floatValue

        guard let inputStream = InputStream(url: url) else {
            return nil
        }
        self.inputStream = inputStream
        super.init(url: url)
    }
}
