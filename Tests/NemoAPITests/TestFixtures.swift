//
//  TestFixtures.swift
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

// MARK: - Path Fixtures
struct UserPath: APIPathParameters {
    var id: String
    static var pathLayout: [APIPathComponent<UserPath>] { [.path("users"), .parameter(.init("id", \.id))] }
}

struct ItemPath: APIPathParameters {
    var id: Int
    static var pathLayout: [APIPathComponent<ItemPath>] { [.path("items"), .parameter(.init("id", \.id))] }
}

struct EmptyConstantPath: APIPathParameters {
    static var pathLayout: [APIPathComponent<EmptyConstantPath>] { [.path(""), .path("x")] }
}

struct SlashConstantPath: APIPathParameters {
    static var pathLayout: [APIPathComponent<SlashConstantPath>] { [.path("a/b")] }
}

struct LeadingSlashConstantPath: APIPathParameters {
    static var pathLayout: [APIPathComponent<LeadingSlashConstantPath>] { [.path("/a")] }
}

struct SpaceConstantPath: APIPathParameters {
    static var pathLayout: [APIPathComponent<SpaceConstantPath>] { [.path("a b")] }
}

struct DotConstantPath: APIPathParameters {
    static var pathLayout: [APIPathComponent<DotConstantPath>] { [.path("..")] }
}

struct UserLookup: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = UserPath
    static var requireAuth: RequireAuth { .none }
    static var method: APIMethod { .GET }
}

/// Mirrors the server: split the raw path on `/`, then percent-decode each segment once.
func serverDecodedSegments(of components: URLComponents) -> [String] {
    components.percentEncodedPath
        .split(separator: "/")
        .map { String($0).removingPercentEncoding ?? String($0) }
}

// MARK: - Query Fixtures
struct OrderedQuery: APIQuery {
    var zebra = 1
    var alpha = "a"
    var mid = "m"
    var beta = "b"
    var omega = 9
    var delta = "d"
}

struct BoolQuery: APIQuery {
    var on = true
    var off = false
}

struct NumberQuery: APIQuery {
    var integer = 42
    var fraction = 1.5
    var whole = 3.0
    var negative = -7
    var beyondDoublePrecision = 9_007_199_254_740_993
    var unsignedMax = UInt64.max
}

struct ArrayQuery: APIQuery {
    var tags = ["a", "b"]
    var empty: [String] = []
}

struct InnerQuery: Codable, Sendable {
    var x = 1
    var y = "z"
}

struct NestedQuery: APIQuery {
    var outer = InnerQuery()
}

struct OptionalQuery: APIQuery {
    var missing: String? = nil
    var present = "k"
}

struct RichQuery: APIQuery {
    enum Level: String, Codable, Sendable { case high }

    var id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var blob = Data([1, 2, 3])
    var level = Level.high
    var counts = [3, 1, 2]
    var labels = ["b": "2", "a": "1"]
    var inner: InnerQuery? = InnerQuery()
    var price = Decimal(string: "3.14")!
    var ratio: Float = 0.1
}

struct NonFiniteQuery: APIQuery {
    var value = Double.infinity
}

struct IntegerWidthsQuery: APIQuery {
    var i8: Int8 = -8
    var i16: Int16 = -16
    var i32: Int32 = -32
    var i64: Int64 = -64
    var u: UInt = 1
    var u8: UInt8 = 8
    var u16: UInt16 = 16
    var u32: UInt32 = 32
    var u64: UInt64 = 64
}

struct ScalarArraysQuery: APIQuery {
    var bools = [true, false]
    var doubles = [0.5, 2.0]
    var floats: [Float] = [0.1]
    var strings = ["s"]
    var i8: [Int8] = [-8]
    var i16: [Int16] = [-16]
    var i32: [Int32] = [-32]
    var i64: [Int64] = [-64]
    var u: [UInt] = [1]
    var u8: [UInt8] = [8]
    var u16: [UInt16] = [16]
    var u32: [UInt32] = [32]
    var u64: [UInt64] = [64]
    var maybe: [String?] = ["x", nil]
}

struct ManualContainersQuery: APIQuery {
    private enum CodingKeys: String, CodingKey { case gone, group, list, parent, child, count, inspected }

    init() {}
    init(from decoder: Decoder) throws { self.init() }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNil(forKey: .gone)

        var group = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .group)
        try group.encode("a", forKey: .child)
        try "e".encode(to: group.superEncoder())

        var list = container.nestedUnkeyedContainer(forKey: .list)
        try list.encode(1)
        var element = list.nestedContainer(keyedBy: CodingKeys.self)
        try element.encode("b", forKey: .child)
        var inner = list.nestedUnkeyedContainer()
        try inner.encode(2)
        try "c".encode(to: list.superEncoder())

        try "d".encode(to: container.superEncoder(forKey: .parent))
        try container.encode(list.count, forKey: .count)

        let paths = container.codingPath.count + group.codingPath.count + list.codingPath.count
        try container.encode(paths + encoder.codingPath.count + encoder.userInfo.count, forKey: .inspected)
    }
}

struct SingleValueRootQuery: APIQuery {
    init() {}
    init(from decoder: Decoder) throws { self.init() }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("x")
    }
}

struct DefaultDateQuery: APIQuery {
    var at: Date
    var until: Date?
}

struct Iso8601DateQuery: APIQuery {
    static var dateEncoding: QueryDateEncoding { .iso8601 }
    var at: Date
}

struct EpochMillisecondsDateQuery: APIQuery {
    static var dateEncoding: QueryDateEncoding { .millisecondsSince1970 }
    var at: Date
}

struct FractionalDateQuery: APIQuery {
    static var dateEncoding: QueryDateEncoding { .iso8601WithFractionalSeconds }
    var at: Date
}

struct ExplicitEpochQuery: APIQuery {
    var at: Date

    private enum CodingKeys: String, CodingKey { case at }

    init(at: Date) {
        self.at = at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        at = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .at))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(at.timeIntervalSince1970, forKey: .at)
    }
}

struct FailingQuery: APIQuery {
    init() {}
    init(from decoder: Decoder) throws { self.init() }
    func encode(to encoder: Encoder) throws {
        throw EncodingError.invalidValue(0, .init(codingPath: [], debugDescription: "forced failure"))
    }
}

struct ArrayRootQuery: APIQuery {
    init() {}
    init(from decoder: Decoder) throws { self.init() }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(1)
    }
}

// MARK: - Cache Fixtures
struct DefaultUncached: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static var requireAuth: RequireAuth { .none }
    static var method: APIMethod { .GET }
}

struct PublicCached: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static var requireAuth: RequireAuth { .none }
    static var method: APIMethod { .GET }
    static var cacheable: Bool { true }
    static var ttl: Duration { .minutes(5) }
}

struct StrictCached: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static var requireAuth: RequireAuth { .strict }
    static var method: APIMethod { .GET }
    static var cacheable: Bool { true }
    static var ttl: Duration { .hours(1) }
}

struct OptionalCached: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static var requireAuth: RequireAuth { .optional }
    static var method: APIMethod { .GET }
    static var cacheable: Bool { true }
    static var ttl: Duration { .seconds(30) }
}

struct SubSecondCached: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static var requireAuth: RequireAuth { .none }
    static var method: APIMethod { .GET }
    static var cacheable: Bool { true }
    static var ttl: Duration { .milliseconds(500) }
}

struct PostCached: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static var requireAuth: RequireAuth { .none }
    static var method: APIMethod { .POST }
    static var cacheable: Bool { true }
    static var ttl: Duration { .minutes(1) }
}

struct ZeroTTLCached: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static var requireAuth: RequireAuth { .none }
    static var method: APIMethod { .GET }
    static var cacheable: Bool { true }
}

struct NegativeTTLCached: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static var requireAuth: RequireAuth { .none }
    static var method: APIMethod { .GET }
    static var cacheable: Bool { true }
    static var ttl: Duration { .seconds(-5) }
}

struct UncachedWithTTL: APIEndpoint {
    typealias ResponseDTO = EmptyParameters
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static var requireAuth: RequireAuth { .none }
    static var method: APIMethod { .GET }
    static var ttl: Duration { .minutes(1) }
}
