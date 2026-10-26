//
//  PathResolutionTests.swift
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

@Suite("resolvePath")
struct PathResolutionTests {
    @Test func plainParameterKeepsSimpleValuesUntouched() throws {
        let components = try UserPath(id: "123").resolvePath()

        #expect(components.percentEncodedPath == "/users/123")
        #expect(components.path == "/users/123")
    }

    @Test func nonStringParameterIsStringified() throws {
        #expect(try ItemPath(id: 7).resolvePath().percentEncodedPath == "/items/7")
    }

    @Test func layoutWithoutComponentsResolvesToRoot() throws {
        #expect(try EmptyParameters().resolvePath().percentEncodedPath == "/")
    }

    @Test(arguments: [
        ("a b", "a%20b"),
        ("a/b", "a%2Fb"),
        ("x?y=1", "x%3Fy=1"),
        ("a#b", "a%23b"),
        ("../admin", "..%2Fadmin"),
        ("한글", "%ED%95%9C%EA%B8%80"),
        ("50%", "50%25"),
        ("a;b+c", "a;b+c"),
    ])
    func parameterStaysOneSegmentAndRoundTripsThroughTheServer(value: String, encoded: String) throws {
        let components = try UserPath(id: value).resolvePath()

        #expect(components.percentEncodedPath == "/users/\(encoded)")
        #expect(components.query == nil)
        #expect(components.fragment == nil)
        #expect(serverDecodedSegments(of: components) == ["users", value])
    }

    @Test func emptyParameterThrowsInsteadOfTrapping() {
        #expect(throws: APIReceiptError.emptyParameter) {
            try UserPath(id: "").resolvePath()
        }
    }

    @Test(arguments: [".", ".."])
    func dotSegmentParameterIsRejected(value: String) {
        #expect(throws: APIReceiptError.invalidPath) {
            try UserPath(id: value).resolvePath()
        }
    }

    @Test func invalidConstantSegmentsAreRejectedInsteadOfDroppedSilently() {
        #expect(throws: APIReceiptError.invalidPath) { try EmptyConstantPath().resolvePath() }
        #expect(throws: APIReceiptError.invalidPath) { try SlashConstantPath().resolvePath() }
        #expect(throws: APIReceiptError.invalidPath) { try LeadingSlashConstantPath().resolvePath() }
        #expect(throws: APIReceiptError.invalidPath) { try SpaceConstantPath().resolvePath() }
        #expect(throws: APIReceiptError.invalidPath) { try DotConstantPath().resolvePath() }
    }

    @Test func endpointBuildsItsPathFromItsPathParameters() throws {
        let components = try UserLookup.makePath(with: UserPath(id: "a b"))

        #expect(components.percentEncodedPath == "/users/a%20b")
    }

    @Test func resolvedPathIsStableAcrossCalls() throws {
        let first = try UserPath(id: "a b/c").resolvePath()
        let second = try UserPath(id: "a b/c").resolvePath()

        #expect(first == second)
    }
}
