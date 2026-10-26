//
//  ErrorDescriptionTests.swift
//  NemoAPI
//
//  Created by Jeongcheol Kim on 10/20/26.
//  Copyright (c) 2026 Jeongcheol Kim (nemois). All rights reserved.
//
//  Licensed under the MIT License.
//  See the LICENSE file in the project root for license information.
//

import Foundation
import NemoAPI
import Testing

@Suite("APIReceiptError")
struct ErrorDescriptionTests {
    @Test(arguments: [
        (APIReceiptError.wrongReceipt, "Wrong Receipt"),
        (APIReceiptError.emptyParameter, "URL Parameter is empty"),
        (APIReceiptError.invalidPath, "URLComponent is invalid"),
    ])
    func localizedDescriptionUsesTheDeclaredMessage(error: APIReceiptError, message: String) {
        #expect(error.localizedDescription == message)
    }
}
