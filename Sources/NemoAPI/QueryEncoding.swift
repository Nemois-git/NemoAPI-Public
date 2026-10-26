//
//  QueryEncoding.swift
//  NemoAPI
//
//  Created by Jeongcheol Kim on 10/20/26.
//  Copyright (c) 2026 Jeongcheol Kim (nemois). All rights reserved.
//
//  Licensed under the MIT License.
//  See the LICENSE file in the project root for license information.
//

import Foundation

/// Collects name/value pairs while a model encodes itself, so every value arrives with its real type
/// and nothing has to be guessed back from text. Arrays repeat the key and nested objects use brackets,
/// the two shapes form-style query decoders read back; nil values yield no item, like an omitted optional.
final class QueryWriter {
    private let dateEncoding: QueryDateEncoding
    private var entries: [(name: String, value: String)] = []
    private var rootWasRejected = false

    private init(dateEncoding: QueryDateEncoding) {
        self.dateEncoding = dateEncoding
    }

    static func items(of model: some Encodable, dateEncoding: QueryDateEncoding) throws -> [URLQueryItem] {
        let writer = QueryWriter(dateEncoding: dateEncoding)
        try model.encode(to: QueryEncoder(writer: writer, name: nil))
        guard !writer.rootWasRejected else { throw APIReceiptError.wrongReceipt }
        return writer.sortedItems()
    }

    fileprivate func add(_ value: String, named name: String) {
        entries.append((name, value))
    }

    fileprivate func add(_ number: some BinaryFloatingPoint & LosslessStringConvertible, named name: String) throws {
        guard number.isFinite else {
            let context = EncodingError.Context(codingPath: [], debugDescription: "Non-finite numbers cannot be sent in a query.")
            throw EncodingError.invalidValue(number, context)
        }
        add(number.queryText, named: name)
    }

    fileprivate func encode(_ value: some Encodable, named name: String) throws {
        switch value {
        case let date as Date:
            add(dateEncoding.text(for: date), named: name)
        case let data as Data:
            add(data.base64EncodedString(), named: name)
        case let decimal as Decimal:
            add(decimal.description, named: name)
        default:
            try value.encode(to: QueryEncoder(writer: self, name: name))
        }
    }

    fileprivate func rejectRoot() {
        rootWasRejected = true
    }

    private func sortedItems() -> [URLQueryItem] {
        entries.enumerated()
            .sorted { ($0.element.name, $0.offset) < ($1.element.name, $1.offset) }
            .map { URLQueryItem(name: $0.element.name, value: $0.element.value) }
    }
}

fileprivate extension QueryDateEncoding {
    func text(for date: Date) -> String {
        switch self {
        case .iso8601: date.formatted(.iso8601)
        case .iso8601WithFractionalSeconds: date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        case .secondsSince1970: date.timeIntervalSince1970.queryText
        case .millisecondsSince1970: (date.timeIntervalSince1970 * 1000).queryText
        }
    }
}

fileprivate extension BinaryFloatingPoint where Self: LosslessStringConvertible {
    var queryText: String {
        rounded() == self && abs(self) < 1e15 ? String(Int64(self)) : description
    }
}

fileprivate struct QueryEncoder: Encoder {
    let writer: QueryWriter
    let name: String?
    var codingPath: [CodingKey] { [] }
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        KeyedEncodingContainer(KeyedQueryContainer<Key>(writer: writer, name: name))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        ValueQueryContainer(writer: writer, name: acceptedName())
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        ValueQueryContainer(writer: writer, name: acceptedName())
    }

    private func acceptedName() -> String {
        guard let name else {
            writer.rejectRoot()
            return ""
        }
        return name
    }
}

fileprivate struct KeyedQueryContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let writer: QueryWriter
    let name: String?
    var codingPath: [CodingKey] { [] }

    private func childName(_ key: Key) -> String {
        name.map { "\($0)[\(key.stringValue)]" } ?? key.stringValue
    }

    mutating func encodeNil(forKey key: Key) throws {}
    mutating func encode(_ value: Bool, forKey key: Key) throws { writer.add(value ? "true" : "false", named: childName(key)) }
    mutating func encode(_ value: String, forKey key: Key) throws { writer.add(value, named: childName(key)) }
    mutating func encode(_ value: Double, forKey key: Key) throws { try writer.add(value, named: childName(key)) }
    mutating func encode(_ value: Float, forKey key: Key) throws { try writer.add(value, named: childName(key)) }
    mutating func encode(_ value: Int, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { writer.add(String(value), named: childName(key)) }
    mutating func encode<Value: Encodable>(_ value: Value, forKey key: Key) throws { try writer.encode(value, named: childName(key)) }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        KeyedEncodingContainer(KeyedQueryContainer<NestedKey>(writer: writer, name: childName(key)))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        ValueQueryContainer(writer: writer, name: childName(key))
    }

    mutating func superEncoder() -> Encoder {
        QueryEncoder(writer: writer, name: name)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        QueryEncoder(writer: writer, name: childName(key))
    }
}

fileprivate final class ValueQueryContainer: UnkeyedEncodingContainer, SingleValueEncodingContainer {
    private let writer: QueryWriter
    private let name: String
    private(set) var count = 0
    var codingPath: [CodingKey] { [] }

    init(writer: QueryWriter, name: String) {
        self.writer = writer
        self.name = name
    }

    private func put(_ text: String) {
        writer.add(text, named: name)
        count += 1
    }

    func encodeNil() throws { count += 1 }
    func encode(_ value: Bool) throws { put(value ? "true" : "false") }
    func encode(_ value: String) throws { put(value) }
    func encode(_ value: Double) throws { try writer.add(value, named: name); count += 1 }
    func encode(_ value: Float) throws { try writer.add(value, named: name); count += 1 }
    func encode(_ value: Int) throws { put(String(value)) }
    func encode(_ value: Int8) throws { put(String(value)) }
    func encode(_ value: Int16) throws { put(String(value)) }
    func encode(_ value: Int32) throws { put(String(value)) }
    func encode(_ value: Int64) throws { put(String(value)) }
    func encode(_ value: UInt) throws { put(String(value)) }
    func encode(_ value: UInt8) throws { put(String(value)) }
    func encode(_ value: UInt16) throws { put(String(value)) }
    func encode(_ value: UInt32) throws { put(String(value)) }
    func encode(_ value: UInt64) throws { put(String(value)) }
    func encode<Value: Encodable>(_ value: Value) throws { try writer.encode(value, named: name); count += 1 }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        count += 1
        return KeyedEncodingContainer(KeyedQueryContainer<NestedKey>(writer: writer, name: name))
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        count += 1
        return ValueQueryContainer(writer: writer, name: name)
    }

    func superEncoder() -> Encoder {
        count += 1
        return QueryEncoder(writer: writer, name: name)
    }
}
