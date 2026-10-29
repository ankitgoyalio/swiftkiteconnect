//
//  ArbitraryJSONDecoding.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation

/// Case constructors keep the recursive policy shared without changing either public enum
/// or allocating an intermediate JSON tree. Child values recurse through Value.init(from:).
func decodeArbitraryJSON<Value: Decodable>(
    from decoder: any Decoder,
    null: Value,
    bool: (Bool) -> Value,
    string: (String) -> Value,
    number: (Decimal) -> Value,
    array: ([Value]) -> Value,
    object: ([String: Value]) -> Value,
) throws -> Value {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
        return null
    } else if let value = try? container.decode(Bool.self) {
        return bool(value)
    } else if let value = try? container.decode(String.self) {
        return string(value)
    } else if let value = try? container.decode(Decimal.self) {
        return number(value)
    } else if let value = try? container.decode([Value].self) {
        return array(value)
    } else {
        return try object(container.decode([String: Value].self))
    }
}
