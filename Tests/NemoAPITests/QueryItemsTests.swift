//
//  QueryItemsTests.swift
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

@Suite("APIQuery")
struct QueryItemsTests {
    private func pairs(_ items: [URLQueryItem]) -> [String] {
        items.map { "\($0.name)=\($0.value ?? "nil")" }
    }

    @Test func itemsAreSortedByNameAndStableAcrossCalls() throws {
        let expected = ["alpha=a", "beta=b", "delta=d", "mid=m", "omega=9", "zebra=1"]

        for _ in 0..<20 {
            #expect(pairs(try OrderedQuery().queryItems) == expected)
        }
    }

    @Test func boolIsWrittenAsWords() throws {
        #expect(pairs(try BoolQuery().queryItems) == ["off=false", "on=true"])
    }

    @Test func numbersKeepTheirExactTextualForm() throws {
        let expected = [
            "beyondDoublePrecision=9007199254740993",
            "fraction=1.5",
            "integer=42",
            "negative=-7",
            "unsignedMax=18446744073709551615",
            "whole=3",
        ]

        #expect(pairs(try NumberQuery().queryItems) == expected)
    }

    @Test func arraysRepeatTheKeyAndEmptyArraysAreOmitted() throws {
        #expect(pairs(try ArrayQuery().queryItems) == ["tags=a", "tags=b"])
    }

    @Test func nestedObjectsUseBracketedNames() throws {
        #expect(pairs(try NestedQuery().queryItems) == ["outer[x]=1", "outer[y]=z"])
    }

    @Test func commonFoundationTypesKeepTheirNaturalTextForm() throws {
        let expected = [
            "blob=AQID",
            "counts=3",
            "counts=1",
            "counts=2",
            "id=00000000-0000-0000-0000-000000000001",
            "inner[x]=1",
            "inner[y]=z",
            "labels[a]=1",
            "labels[b]=2",
            "level=high",
            "price=3.14",
            "ratio=0.1",
        ]

        #expect(pairs(try RichQuery().queryItems) == expected)
    }

    @Test func everyIntegerWidthIsWrittenAsPlainDigits() throws {
        let expected = [
            "i16=-16", "i32=-32", "i64=-64", "i8=-8",
            "u=1", "u16=16", "u32=32", "u64=64", "u8=8",
        ]

        #expect(pairs(try IntegerWidthsQuery().queryItems) == expected)
    }

    @Test func arraysOfEveryScalarRepeatTheKeyAndSkipNilElements() throws {
        let expected = [
            "bools=true", "bools=false",
            "doubles=0.5", "doubles=2",
            "floats=0.1",
            "i16=-16", "i32=-32", "i64=-64", "i8=-8",
            "maybe=x",
            "strings=s",
            "u=1", "u16=16", "u32=32", "u64=64", "u8=8",
        ]

        #expect(pairs(try ScalarArraysQuery().queryItems) == expected)
    }

    @Test func manuallyDrivenContainersFlattenIntoTheSameNames() throws {
        let expected = [
            "count=4",
            "group=e",
            "group[child]=a",
            "inspected=0",
            "list=1",
            "list=2",
            "list=c",
            "list[child]=b",
            "parent=d",
        ]

        #expect(pairs(try ManualContainersQuery().queryItems) == expected)
    }

    @Test func singleValueAtTheRootIsRejected() {
        #expect(throws: APIReceiptError.wrongReceipt) { try SingleValueRootQuery().queryItems }
    }

    @Test func nonFiniteNumbersAreRejected() {
        #expect(throws: EncodingError.self) { try NonFiniteQuery().queryItems }
    }

    @Test func nilOptionalIsOmitted() throws {
        #expect(pairs(try OptionalQuery().queryItems) == ["present=k"])
    }

    @Test func datesDefaultToSecondsSince1970() throws {
        let query = DefaultDateQuery(at: Date(timeIntervalSince1970: 1_700_000_000.5))

        #expect(pairs(try query.queryItems) == ["at=1700000000.5"])
    }

    @Test func defaultMatchesATypeThatEncodesTheEpochItself() throws {
        let moment = Date(timeIntervalSince1970: 1_700_000_000.25)

        let byDefault = try DefaultDateQuery(at: moment).queryItems
        let explicit = try ExplicitEpochQuery(at: moment).queryItems

        #expect(pairs(byDefault) == pairs(explicit))
    }

    @Test func queryTypeCanOverrideToMilliseconds() throws {
        let query = EpochMillisecondsDateQuery(at: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(pairs(try query.queryItems) == ["at=1700000000000"])
    }

    @Test func iso8601OverrideDropsFractionalSeconds() throws {
        let query = Iso8601DateQuery(at: Date(timeIntervalSince1970: 1_700_000_000.5))

        #expect(pairs(try query.queryItems) == ["at=2023-11-14T22:13:20Z"])
    }

    @Test func fractionalIso8601OverrideKeepsMilliseconds() throws {
        let query = FractionalDateQuery(at: Date(timeIntervalSince1970: 1_700_000_000.5))

        #expect(pairs(try query.queryItems) == ["at=2023-11-14T22:13:20.500Z"])
    }

    @Test func nilDateIsOmitted() throws {
        let query = DefaultDateQuery(at: Date(timeIntervalSince1970: 0), until: nil)

        #expect(pairs(try query.queryItems) == ["at=0"])
    }

    @Test func emptyQueryHasNoItems() throws {
        #expect(try EmptyParameters().queryItems.isEmpty)
    }

    @Test func encodingFailureIsThrownInsteadOfBecomingAnEmptyQuery() {
        #expect(throws: EncodingError.self) { try FailingQuery().queryItems }
    }

    @Test func queryThatDoesNotEncodeToAnObjectIsRejected() {
        #expect(throws: APIReceiptError.wrongReceipt) { try ArrayRootQuery().queryItems }
    }
}
