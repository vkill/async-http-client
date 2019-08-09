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

import AsyncHTTPClient
import NIO
import Foundation
import XCTest

class ZlibDecompressionTests: XCTestCase {
    func testDecompressGzip() throws {
        let zlibDecompression = ZlibDecompression()
 
        XCTAssertEqual(try zlibDecompression.decompressGzip(compressedBytes: [UInt8](Data(base64Encoded: "H4sIAAAAAAAAAzM0MuYCAAj9gloEAAAA")!)), [UInt8](Data("123".utf8)))
    }
}
