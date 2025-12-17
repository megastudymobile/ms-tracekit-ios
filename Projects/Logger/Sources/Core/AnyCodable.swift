// AnyCodable.swift
// Logger
//
// Created by jimmy on 2025-12-15.

import Foundation

/// 타입 소거된 Codable 래퍼
/// - Note: metadata에 다양한 타입의 값을 저장하기 위해 사용
public struct AnyCodable: Codable, @unchecked Sendable, Equatable, CustomStringConvertible {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable cannot decode value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encode(String(describing: value))
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        default:
            return false
        }
    }

    public var description: String {
        String(describing: value)
    }
}

// MARK: - ExpressibleBy Protocols

extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral _: ()) {
        value = NSNull()
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        value = elements
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        value = Dictionary(uniqueKeysWithValues: elements)
    }
}
