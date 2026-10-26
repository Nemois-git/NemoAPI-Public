//
//  NemoAPI.swift
//  NemoAPI
//
//  Created by Jeongcheol Kim on 7/14/26.
//  Copyright (c) 2026 Jeongcheol Kim (nemois). All rights reserved.
//
//  Licensed under the MIT License.
//  See the LICENSE file in the project root for license information.
//

import Foundation

// MARK: - Contract Primitives
public enum APIReceiptError: LocalizedError, Sendable {
    case wrongReceipt
    case emptyParameter
    case invalidPath

    public var errorDescription: String? {
        switch self {
        case .wrongReceipt: "Wrong Receipt"
        case .emptyParameter: "URL Parameter is empty"
        case .invalidPath: "URLComponent is invalid"
        }
    }
}

public enum APIMethod: String, Sendable {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
}

public enum RequireAuth: Sendable {
    case strict
    case optional
    case none
}

// MARK: - Path
public struct PathParamExtractor<Param: Sendable>: Sendable {
    public let name: String
    public let extract: @Sendable (Param) -> String

    public init<Value: CustomStringConvertible & Sendable>(_ name: String, _ keyPath: KeyPath<Param, Value> & Sendable) {
        self.name = name
        self.extract = { "\($0[keyPath: keyPath])" }
    }
}

public enum APIPathComponent<Param: APIPathParameters>: Sendable {
    case path(String)
    case parameter(PathParamExtractor<Param>)
}

public protocol APIPathParameters: Codable, Sendable {
    static var pathLayout: [APIPathComponent<Self>] { get }
}

public extension APIPathParameters {
    /// Encodes each parameter value on its own so a `/`, `?` or `#` inside it cannot reshape
    /// the path the server routes on. Constants are validated instead, since the router
    /// matches them undecoded.
    func resolvePath() throws -> URLComponents {
        let segments = try Self.pathLayout.map { component -> String in
            switch component {
            case .path(let path):
                return try PathSegment.validatedConstant(path)
            case .parameter(let extractor):
                return try PathSegment.encodedParameter(extractor.extract(self))
            }
        }

        var components = URLComponents()
        components.percentEncodedPath = "/" + segments.joined(separator: "/")
        return components
    }
}

/// The server splits the raw path on `/` first and percent-decodes each segment afterwards,
/// so a parameter value must never keep a literal `/`.
/// Constant segments are matched undecoded, so they must already be URL-safe.
fileprivate enum PathSegment {
    private static let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))

    static func encodedParameter(_ value: String) throws -> String {
        guard !value.isEmpty else { throw APIReceiptError.emptyParameter }
        guard !isDotSegment(value),
              let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw APIReceiptError.invalidPath
        }
        return encoded
    }

    static func validatedConstant(_ value: String) throws -> String {
        guard !value.isEmpty,
              !isDotSegment(value),
              value.rangeOfCharacter(from: allowed.inverted) == nil else {
            throw APIReceiptError.invalidPath
        }
        return value
    }

    private static func isDotSegment(_ value: String) -> Bool {
        value == "." || value == ".."
    }
}

// MARK: - Query
/// Wire form of `Date` values in a query; a query type overrides it through `dateEncoding`.
public enum QueryDateEncoding: Sendable {
    case iso8601
    case iso8601WithFractionalSeconds
    case secondsSince1970
    case millisecondsSince1970
}

public protocol APIQuery: Codable, Sendable {
    /// Seconds since 1970 is what query decoders read by default, so it needs no server setup; override for ISO 8601.
    static var dateEncoding: QueryDateEncoding { get }
}

public extension APIQuery {
    static var dateEncoding: QueryDateEncoding { .secondsSince1970 }
}

/// Items are sorted by name so one query always yields one URL, which keeps cache keys stable.
/// `URLComponents` leaves `+` literal, as URI rules allow, but form-style servers read it as a space.
public extension APIQuery {
    /// Throws rather than yielding `[]`, so an encoding failure is never sent as an empty query.
    var queryItems: [URLQueryItem] {
        get throws {
            try QueryWriter.items(of: self, dateEncoding: Self.dateEncoding)
        }
    }
}

// MARK: - Empty Parameters
public struct EmptyParameters: APIQuery, APIPathParameters, Sendable {
    public static var pathLayout: [APIPathComponent<EmptyParameters>] { [] }
    public init() {}
}

// MARK: - Endpoint Contract
public protocol APIEndpoint: Sendable {
    associatedtype RequestDTO: Codable, Sendable = EmptyParameters
    associatedtype ResponseDTO: Codable, Sendable
    associatedtype Query: APIQuery
    associatedtype PathParameters: APIPathParameters

    static var requireAuth: RequireAuth { get }
    static var method: APIMethod { get }

    /// Cache declaration shared by server and client; off by default so nothing serves stale data by accident.
    static var cacheable: Bool { get }
    static var ttl: Duration { get }
}

public extension APIEndpoint {
    static var cacheable: Bool { false }
    static var ttl: Duration { .zero }
}

public extension APIEndpoint {
    static func makePath(with params: PathParameters) throws -> URLComponents {
        try params.resolvePath()
    }
}

// MARK: - Cache Contract
/// A cache declaration is consistent when all three hold:
/// 1. Only `GET` is cacheable; request bodies are not part of the cache key.
/// 2. A cacheable endpoint has a positive `ttl`, otherwise it caches nothing.
/// 3. A non-cacheable endpoint has no `ttl`, so the value never misleads.
public extension APIEndpoint {
    /// Consumers assert this in their own tests, since this package cannot enumerate their endpoints.
    static var isCacheContractValid: Bool {
        cacheable ? (method == .GET && ttl > .zero) : (ttl == .zero)
    }

    /// Rounded up so a valid sub-second `ttl` never becomes `max-age=0`.
    static var maxAgeSeconds: Int {
        guard cacheable else { return 0 }
        let parts = ttl.components
        guard parts.seconds >= 0 else { return 0 }
        return Int(clamping: parts.attoseconds > 0 ? parts.seconds + 1 : parts.seconds)
    }

    /// Any auth makes a response user-specific, so only unauthenticated endpoints may be `public`.
    static var cacheControlValue: String {
        guard cacheable, isCacheContractValid else { return "no-store" }
        let scope = requireAuth == RequireAuth.none ? "public" : "private"
        return "\(scope), max-age=\(maxAgeSeconds)"
    }
}

// MARK: - TTL Readability Helpers
/// `.minutes(5)` reads as an intent; `.seconds(300)` reads as arithmetic.
public extension Duration {
    static func minutes(_ value: Int) -> Duration { .seconds(value * 60) }
    static func hours(_ value: Int) -> Duration { .seconds(value * 60 * 60) }
    static func days(_ value: Int) -> Duration { .seconds(value * 24 * 60 * 60) }
}
