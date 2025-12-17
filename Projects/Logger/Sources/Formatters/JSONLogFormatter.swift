// JSONLogFormatter.swift
// Logger
//
// Created by jimmy on 2025-12-15.

import Foundation

/// JSON 형식 로그 포맷터
/// - Note: Datadog, ELK 등 로그 분석 시스템 연동용
public struct JSONLogFormatter: LogFormatter {
    /// JSON 들여쓰기 여부
    public let prettyPrint: Bool

    /// 날짜 포맷터
    private nonisolated(unsafe) let dateFormatter: ISO8601DateFormatter

    /// JSON 인코더 (Swift 6에서 Sendable이므로 nonisolated(unsafe) 불필요)
    private let encoder: JSONEncoder

    public init(prettyPrint: Bool = false) {
        self.prettyPrint = prettyPrint

        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
    }

    public func format(_ message: LogMessage) -> String {
        var logDict: [String: Any] = [
            "id": message.id.uuidString,
            "timestamp": dateFormatter.string(from: message.timestamp),
            "level": message.level.name,
            "levelValue": message.level.rawValue,
            "category": message.category,
            "message": message.message,
            "file": message.fileName,
            "function": message.function,
            "line": message.line,
        ]

        if let metadata = message.metadata {
            logDict["metadata"] = metadata.mapValues { $0.value }
        }

        if let userContext = message.userContext {
            logDict["context"] = userContext.toDictionary()
        }

        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: logDict,
                options: prettyPrint ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
            )
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to serialize log message\"}"
        }
    }
}
