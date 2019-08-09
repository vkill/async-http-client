//===----------------------------------------------------------------------===//
//
// This source file is part of the AsyncHTTPClient open source project
//
// Copyright (c) 2018-2019 Swift Server Working Group and the AsyncHTTPClient project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of AsyncHTTPClient project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import CNIOExtrasZlib

public struct ZlibDecompressionError: Error {
    
    public let code: Int32
    public let message: String
    
    init(code: Int32, msg: UnsafePointer<CChar>?) {
        self.code = code
        if let msg = msg, let message = String(validatingUTF8: msg) {
            self.message = message
        } else {
            self.message = "Unknown"
        }
    }
}

public final class ZlibDecompression {
    public init() {
    }
    
    public func decompressGzip(compressedBytes: [UInt8]) throws -> [UInt8] {
        var compressedBuffer = ByteBufferAllocator().buffer(capacity: compressedBytes.count)
        compressedBuffer.writeBytes(compressedBytes)
        var outputBuffer = ByteBufferAllocator().buffer(capacity: 0)
        try decompressGzip(compressedBuffer: &compressedBuffer, outputBuffer: &outputBuffer)
        return outputBuffer.readBytes(length: outputBuffer.readableBytes)!
    }

    public func decompressDeflate(compressedBuffer: inout ByteBuffer, outputBuffer: inout ByteBuffer) throws {
        try decompress(compressedBuffer: &compressedBuffer, outputBuffer: &outputBuffer, windowSize: 15)
    }
    
    public func decompressGzip(compressedBuffer: inout ByteBuffer, outputBuffer: inout ByteBuffer) throws {
        try decompress(compressedBuffer: &compressedBuffer, outputBuffer: &outputBuffer, windowSize: 16 + 15)
    }
    
    private func decompress(compressedBuffer: inout ByteBuffer, outputBuffer: inout ByteBuffer, windowSize: Int32) throws {
        var stream = z_stream()
        
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        var rc = CNIOExtrasZlib_inflateInit2(&stream, windowSize)
        guard rc == Z_OK else {
            throw ZlibDecompressionError(code: rc, msg: stream.msg)
        }
        
        repeat {
            compressedBuffer.withUnsafeMutableReadableUInt8Bytes { inputPointer in
                stream.next_in = inputPointer.baseAddress!
                stream.avail_in = UInt32(inputPointer.count)
                
                outputBuffer.writeWithUnsafeMutableUInt8Bytes { outputPointer -> Int in
                    stream.next_out = outputPointer.baseAddress!
                    stream.avail_out = UInt32(outputPointer.count)
                    
                    rc = inflate(&stream, Z_FINISH)
                    
                    stream.next_out = nil
                    
                    return outputPointer.count - Int(stream.avail_out)
                }
                
                stream.next_in = nil
            }
        } while rc == Z_OK
        
        guard inflateEnd(&stream) == Z_OK, rc == Z_STREAM_END else {
            throw ZlibDecompressionError(code: rc, msg: stream.msg)
        }
    }
}

///
/// https://github.com/apple/swift-nio-extras/blob/master/Tests/NIOHTTPCompressionTests/HTTPResponseCompressorTest.swift
///
private extension ByteBuffer {
    @discardableResult
    mutating func withUnsafeMutableReadableUInt8Bytes<T>(_ body: (UnsafeMutableBufferPointer<UInt8>) throws -> T) rethrows -> T {
        return try self.withUnsafeMutableReadableBytes { (ptr: UnsafeMutableRawBufferPointer) -> T in
            let baseInputPointer = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self)
            let inputBufferPointer = UnsafeMutableBufferPointer(start: baseInputPointer, count: ptr.count)
            return try body(inputBufferPointer)
        }
    }
    
    @discardableResult
    mutating func writeWithUnsafeMutableUInt8Bytes(_ body: (UnsafeMutableBufferPointer<UInt8>) throws -> Int) rethrows -> Int {
        return try self.writeWithUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> Int in
            let baseInputPointer = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self)
            let inputBufferPointer = UnsafeMutableBufferPointer(start: baseInputPointer, count: ptr.count)
            return try body(inputBufferPointer)
        }
    }
}
