// PerformanceTracerTests.swift
// TraceKitTests
//
// Created by jimmy on 2025-12-15.

import Foundation
import Testing
@testable import TraceKit

// MARK: - Test Helpers

/// 로그 메시지 데이터
private struct LogMessage {
    let level: TraceLevel
    let message: String
    let category: String
    let metadata: [String: AnyCodable]
}

/// 테스트용 로그 수집기 (동시성 안전)
private actor LogCollector {
    var messages: [LogMessage] = []

    func record(level: TraceLevel, message: String, category: String, metadata: [String: AnyCodable]) {
        messages.append(LogMessage(level: level, message: message, category: category, metadata: metadata))
    }

    func getMessages() -> [LogMessage] {
        return messages
    }

    func getLastMessage() -> String? {
        return messages.last?.message
    }

    func getLastLevel() -> TraceLevel? {
        return messages.last?.level
    }

    func getLastCategory() -> String? {
        return messages.last?.category
    }

    func getCallCount() -> Int {
        return messages.count
    }

    func reset() {
        messages.removeAll()
    }
}

// MARK: - PerformanceTracer Tests

struct PerformanceTracerTests {
    // MARK: - Start Span Tests

    @Test("span 시작 시 ID 반환")
    func startSpanReturnsId() async {
        // Given
        let tracer = PerformanceTracer()

        // When
        let spanId = await tracer.startSpan(name: "test")

        // Then
        #expect(spanId != UUID())
    }

    @Test("span 시작 시 활성 카운트 증가")
    func startSpanIncreasesActiveCount() async {
        // Given
        let tracer = PerformanceTracer()

        // When
        _ = await tracer.startSpan(name: "test1")
        _ = await tracer.startSpan(name: "test2")

        // Then
        let count = await tracer.activeSpanCount
        #expect(count == 2)
    }

    // MARK: - End Span Tests

    @Test("span 종료 시 활성 카운트 감소")
    func endSpanDecreasesActiveCount() async {
        // Given
        let tracer = PerformanceTracer()
        let spanId = await tracer.startSpan(name: "test")

        // When
        _ = await tracer.endSpan(id: spanId)

        // Then
        let count = await tracer.activeSpanCount
        #expect(count == 0)
    }

    @Test("span 종료 시 완료된 span 반환")
    func endSpanReturnsCompletedSpan() async {
        // Given
        let tracer = PerformanceTracer()
        let spanId = await tracer.startSpan(name: "fetchUser")

        // When
        let completedSpan = await tracer.endSpan(id: spanId)

        // Then
        #expect(completedSpan != nil)
        #expect(completedSpan?.name == "fetchUser")
        #expect(completedSpan?.durationMs != nil)
    }

    @Test("존재하지 않는 span 종료 시 nil")
    func endNonExistentSpanReturnsNil() async {
        // Given
        let tracer = PerformanceTracer()
        let fakeId = UUID()

        // When
        let result = await tracer.endSpan(id: fakeId)

        // Then
        #expect(result == nil)
    }

    @Test("span 종료 시 메타데이터 추가")
    func endSpanWithMetadata() async {
        // Given
        let tracer = PerformanceTracer()
        let spanId = await tracer.startSpan(name: "api")

        // When
        let completedSpan = await tracer.endSpan(
            id: spanId,
            metadata: ["statusCode": AnyCodable(200)]
        )

        // Then
        #expect(completedSpan?.metadata["statusCode"] != nil)
    }

    // MARK: - Measure Tests

    @Test("measure로 비동기 작업 측정")
    func measureAsyncOperation() async {
        // Given
        let tracer = PerformanceTracer()

        // When
        let result = await tracer.measure(name: "compute") {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            return 42
        }

        // Then
        #expect(result == 42)

        let count = await tracer.activeSpanCount
        #expect(count == 0)
    }

    @Test("measure에서 에러 발생 시 span 종료")
    func measureEndsSpanOnError() async throws {
        // Given
        let tracer = PerformanceTracer()

        struct TestError: Error {}

        // When & Then
        do {
            _ = try await tracer.measure(name: "failing") {
                throw TestError()
            }
            Issue.record("Expected error to be thrown")
        } catch {
            // 에러 발생해도 span은 종료되어야 함
            let count = await tracer.activeSpanCount
            #expect(count == 0)
        }
    }

    // MARK: - Cancel All Spans Tests

    @Test("모든 span 취소")
    func cancelAllSpans() async {
        // Given
        let tracer = PerformanceTracer()
        _ = await tracer.startSpan(name: "span1")
        _ = await tracer.startSpan(name: "span2")
        _ = await tracer.startSpan(name: "span3")

        // When
        await tracer.cancelAllSpans()

        // Then
        let count = await tracer.activeSpanCount
        #expect(count == 0)
    }

    // MARK: - Parent Span Tests

    @Test("부모 span ID 설정")
    func parentSpanId() async {
        // Given
        let tracer = PerformanceTracer()
        let parentId = await tracer.startSpan(name: "parent")

        // When
        let childId = await tracer.startSpan(name: "child", parentId: parentId)

        // Then
        #expect(childId != parentId)

        let count = await tracer.activeSpanCount
        #expect(count == 2)
    }

    // MARK: - Log Handler Tests

    @Test("logHandler 설정 후 span 종료 시 로그 호출")
    func logHandlerCalledOnEndSpan() async {
        // Given
        let tracer = PerformanceTracer()
        let collector = LogCollector()

        await tracer.setLogHandler { level, message, category, metadata in
            await collector.record(level: level, message: message, category: category, metadata: metadata)
        }

        // When
        let spanId = await tracer.startSpan(name: "test_span")
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        _ = await tracer.endSpan(id: spanId)

        // Then
        let loggedLevel = await collector.getLastLevel()
        let loggedMessage = await collector.getLastMessage()
        let loggedCategory = await collector.getLastCategory()

        #expect(loggedLevel == .debug)
        #expect(loggedMessage?.contains("test_span") == true)
        #expect(loggedMessage?.contains("completed") == true)
        #expect(loggedCategory == "Performance")
    }

    @Test("자식 span 종료 시 들여쓰기 포함")
    func childSpanHasIndentation() async {
        // Given
        let tracer = PerformanceTracer()
        let collector = LogCollector()

        await tracer.setLogHandler { level, message, category, metadata in
            await collector.record(level: level, message: message, category: category, metadata: metadata)
        }

        // When
        let parentId = await tracer.startSpan(name: "parent")
        let childId = await tracer.startSpan(name: "child", parentId: parentId)
        _ = await tracer.endSpan(id: childId)
        _ = await tracer.endSpan(id: parentId) // 부모 종료 시 자식 로그도 함께 출력됨

        // Then
        let messages = await collector.getMessages()
        #expect(messages.count == 2, "부모와 자식 메시지가 있어야 함")

        // 자식 메시지는 두 번째 메시지
        let childMessage = messages.last
        #expect(childMessage != nil, "child span 메시지가 있어야 함")
        #expect(childMessage?.message.contains("└") == true)
        #expect(childMessage?.message.contains("child") == true)
    }

    @Test("부모 span 종료 시 시작 표시")
    func parentSpanHasStartIndicator() async {
        // Given
        let tracer = PerformanceTracer()
        let collector = LogCollector()

        await tracer.setLogHandler { level, message, category, metadata in
            await collector.record(level: level, message: message, category: category, metadata: metadata)
        }

        // When
        let parentId = await tracer.startSpan(name: "parent")
        _ = await tracer.endSpan(id: parentId)

        // Then
        let loggedMessage = await collector.getLastMessage()
        #expect(loggedMessage?.hasPrefix("▶ ") == true)
        #expect(loggedMessage?.contains("parent") == true)
    }

    @Test("logHandler 없이 span 종료 시 정상 동작")
    func endSpanWithoutLogHandler() async {
        // Given
        let tracer = PerformanceTracer()

        // When
        let spanId = await tracer.startSpan(name: "test")
        let result = await tracer.endSpan(id: spanId)

        // Then
        #expect(result != nil)
        #expect(result?.name == "test")
    }

    @Test("logHandler를 나중에 설정해도 동작")
    func setLogHandlerAfterInit() async {
        // Given
        let tracer = PerformanceTracer()
        let spanId = await tracer.startSpan(name: "before_handler")
        _ = await tracer.endSpan(id: spanId) // 로그 없음

        let collector = LogCollector()
        await tracer.setLogHandler { level, message, category, metadata in
            await collector.record(level: level, message: message, category: category, metadata: metadata)
        }

        // When
        let spanId2 = await tracer.startSpan(name: "after_handler")
        _ = await tracer.endSpan(id: spanId2)

        // Then
        let callCount = await collector.getCallCount()
        #expect(callCount == 1)
    }
}
