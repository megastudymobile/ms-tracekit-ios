// PrettyTraceFormatterTests.swift
// TraceKitTests
//
// Created by jimmy on 2025-12-15.

import Foundation
import Testing
@testable import TraceKit

// MARK: - PrettyTraceFormatter Tests

struct PrettyTraceFormatterTests {
    // MARK: - Basic Formatting Tests

    @Test("기본 메시지 포맷팅")
    func formatBasicMessage() {
        // Given
        let formatter = PrettyTraceFormatter.standard
        let message = TraceMessage(
            level: .info,
            message: "Test message",
            category: "Test",
            file: "/path/to/TestFile.swift",
            function: "testFunc",
            line: 42
        )

        // When
        let result = formatter.format(message)

        // Then
        #expect(result.contains("INFO"))
        #expect(result.contains("[Test]"))
        #expect(result.contains("Test message"))
    }

    // MARK: - Emoji Tests

    @Test("이모지 사용 시 레벨 이모지 포함")
    func includesEmojiWhenEnabled() {
        // Given
        let formatter = PrettyTraceFormatter(useEmoji: true)
        let message = TraceMessage(
            level: .error,
            message: "Error",
            category: "Test",
            file: #file,
            function: #function,
            line: #line
        )

        // When
        let result = formatter.format(message)

        // Then
        #expect(result.contains("❌"))
    }

    @Test("이모지 비활성화 시 대괄호 사용")
    func useBracketsWhenEmojiDisabled() {
        // Given
        let formatter = PrettyTraceFormatter(useEmoji: false)
        let message = TraceMessage(
            level: .info,
            message: "Info",
            category: "Test",
            file: #file,
            function: #function,
            line: #line
        )

        // When
        let result = formatter.format(message)

        // Then
        #expect(result.contains("[INFO]"))
    }

    // MARK: - Timestamp Tests

    @Test("타임스탬프 포함 옵션")
    func includesTimestampWhenEnabled() {
        // Given
        let formatter = PrettyTraceFormatter(includeTimestamp: true)
        let message = TraceMessage(
            level: .info,
            message: "Test",
            category: "Test",
            file: #file,
            function: #function,
            line: #line
        )

        // When
        let result = formatter.format(message)

        // Then
        // HH:mm:ss.SSS 형식 확인 (시간:분:초.밀리초)
        #expect(result.contains(":"))
    }

    @Test("타임스탬프 제외 옵션")
    func excludesTimestampWhenDisabled() {
        // Given
        let formatter = PrettyTraceFormatter(includeTimestamp: false)
        let fixedTime = Date()
        let message = TraceMessage(
            level: .info,
            message: "Test",
            category: "Test",
            timestamp: fixedTime,
            file: #file,
            function: #function,
            line: #line
        )

        // When
        let result = formatter.format(message)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let timeString = dateFormatter.string(from: fixedTime)

        // Then
        // 타임스탬프가 첫 부분에 없어야 함
        #expect(!result.hasPrefix(timeString))
    }

    // MARK: - Location Tests

    @Test("위치 정보 포함")
    func includesLocationWhenEnabled() {
        // Given
        let formatter = PrettyTraceFormatter(includeLocation: true)
        let message = TraceMessage(
            level: .info,
            message: "Test",
            category: "Test",
            file: "/path/to/MyFile.swift",
            function: "myFunc",
            line: 100
        )

        // When
        let result = formatter.format(message)

        // Then
        #expect(result.contains("MyFile.swift"))
        #expect(result.contains(":100"))
    }

    @Test("위치 정보 제외")
    func excludesLocationWhenDisabled() {
        // Given
        let formatter = PrettyTraceFormatter(includeLocation: false)
        let message = TraceMessage(
            level: .info,
            message: "Test",
            category: "Test",
            file: "/path/to/MyFile.swift",
            function: "myFunc",
            line: 100
        )

        // When
        let result = formatter.format(message)

        // Then
        #expect(!result.contains("MyFile.swift"))
    }

    // MARK: - Metadata Tests

    @Test("메타데이터 포함")
    func includesMetadataWhenEnabled() {
        // Given
        let formatter = PrettyTraceFormatter(includeMetadata: true)
        let message = TraceMessage(
            level: .info,
            message: "Test",
            category: "Test",
            metadata: ["key": AnyCodable("value")],
            file: #file,
            function: #function,
            line: #line
        )

        // When
        let result = formatter.format(message)

        // Then
        #expect(result.contains("key:"))
        #expect(result.contains("value"))
    }

    @Test("빈 메타데이터는 표시 안 함")
    func excludesEmptyMetadata() {
        // Given
        let formatter = PrettyTraceFormatter(includeMetadata: true)
        let message = TraceMessage(
            level: .info,
            message: "Test",
            category: "Test",
            metadata: [:],
            file: #file,
            function: #function,
            line: #line
        )

        // When
        let result = formatter.format(message)

        // Then
        #expect(!result.contains("{"))
    }

    // MARK: - Preset Tests

    @Test("minimal 프리셋")
    func minimalPreset() {
        // Given
        let formatter = PrettyTraceFormatter.minimal
        let message = TraceMessage(
            level: .warning,
            message: "Warning",
            category: "Test",
            file: #file,
            function: #function,
            line: #line
        )

        // When
        let result = formatter.format(message)

        // Then
        #expect(result.contains("⚠️"))
        #expect(result.contains("WARNING"))
        #expect(!result.contains(".swift"))
    }

    @Test("verbose 프리셋")
    func verbosePreset() {
        // Given
        let formatter = PrettyTraceFormatter.verbose
        let message = TraceMessage(
            level: .debug,
            message: "Debug",
            category: "Test",
            metadata: ["key": AnyCodable("value")],
            file: "/path/to/File.swift",
            function: "func",
            line: 10
        )

        // When
        let result = formatter.format(message)

        // Then
        #expect(result.contains("🔍"))
        #expect(result.contains("File.swift"))
        #expect(result.contains("key:"))
    }
}
