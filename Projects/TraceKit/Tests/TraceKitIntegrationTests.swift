// TraceKitIntegrationTests.swift
// TraceKitTests
//
// Created by jimmy on 2026-02-04.

import Foundation
import Testing
@testable import TraceKit

// MARK: - TraceKit Integration Tests

struct TraceKitIntegrationTests {
    // MARK: - PerformanceTracer Integration Tests

    @Test("TraceKit 빌더로 생성 시 PerformanceTracer가 로그 파이프라인에 연결됨")
    @TraceKitActor
    func performanceTracerConnectedToLogPipeline() async {
        // Given
        var loggedMessages: [String] = []
        let destination = InMemoryTestDestination { message in
            loggedMessages.append(message.message)
        }

        let traceKit = await TraceKitBuilder()
            .addDestination(destination)
            .with(configuration: .debug)
            .build()

        // TraceKit을 공유 인스턴스로 설정하고 tracer 연결
        TraceKit.setShared(traceKit)
        await traceKit.connectTracerToLogging()

        // When
        let spanId = await traceKit.tracer.startSpan(name: "test_operation")
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        _ = await traceKit.tracer.endSpan(id: spanId)

        // 버퍼 플러시
        await traceKit.flush()

        // Then
        #expect(loggedMessages.count > 0)
        #expect(loggedMessages.contains { $0.contains("test_operation") && $0.contains("completed") })
    }

    @Test("buildAsShared()로 생성 시 자동으로 tracer 연결됨")
    @TraceKitActor
    func buildAsSharedAutoConnectsTracer() async {
        // Given
        var loggedMessages: [String] = []
        let destination = InMemoryTestDestination { message in
            loggedMessages.append(message.message)
        }

        _ = await TraceKitBuilder()
            .addDestination(destination)
            .with(configuration: .debug)
            .buildAsShared()

        // When
        let spanId = await TraceKit.async.tracer.startSpan(name: "auto_connected_span")
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        _ = await TraceKit.async.tracer.endSpan(id: spanId)

        // 버퍼 플러시
        await TraceKit.async.flush()

        // Then
        #expect(loggedMessages.count > 0)
        #expect(loggedMessages.contains { $0.contains("auto_connected_span") && $0.contains("completed") })
    }

    @Test("measure() 메서드도 로그 파이프라인으로 전송됨")
    @TraceKitActor
    func measureSendsToLogPipeline() async {
        // Given
        var loggedMessages: [String] = []
        let destination = InMemoryTestDestination { message in
            loggedMessages.append(message.message)
        }

        _ = await TraceKitBuilder()
            .addDestination(destination)
            .with(configuration: .debug)
            .buildAsShared()

        // When
        let result = await TraceKit.async.measure(name: "compute_task") {
            try? await Task.sleep(nanoseconds: 5_000_000)
            return 42
        }

        // 버퍼 플러시
        await TraceKit.async.flush()

        // Then
        #expect(result == 42)
        #expect(loggedMessages.count > 0)
        #expect(loggedMessages.contains { $0.contains("compute_task") && $0.contains("completed") })
    }

    @Test("카테고리가 Performance로 설정됨")
    @TraceKitActor
    func tracerLogsHavePerformanceCategory() async {
        // Given
        var loggedCategories: [String] = []
        let destination = InMemoryTestDestination { message in
            loggedCategories.append(message.category)
        }

        _ = await TraceKitBuilder()
            .addDestination(destination)
            .with(configuration: .debug)
            .buildAsShared()

        // When
        let spanId = await TraceKit.async.tracer.startSpan(name: "test")
        _ = await TraceKit.async.tracer.endSpan(id: spanId)
        await TraceKit.async.flush()

        // Then
        #expect(loggedCategories.contains("Performance"))
    }

    @Test("부모-자식 span의 들여쓰기가 올바르게 표시됨")
    @TraceKitActor
    func parentChildSpanIndentation() async {
        // Given
        var loggedMessages: [String] = []
        let destination = InMemoryTestDestination { message in
            loggedMessages.append(message.message)
        }

        _ = await TraceKitBuilder()
            .addDestination(destination)
            .with(configuration: .debug)
            .buildAsShared()

        // When
        let parentId = await TraceKit.async.tracer.startSpan(name: "parent_operation")
        let childId = await TraceKit.async.tracer.startSpan(name: "child_operation", parentId: parentId)

        _ = await TraceKit.async.tracer.endSpan(id: childId)
        _ = await TraceKit.async.tracer.endSpan(id: parentId)

        await TraceKit.async.flush()

        // Then
        #expect(loggedMessages.count == 2)

        // 자식 span은 들여쓰기 포함
        let childMessage = loggedMessages.first { $0.contains("child_operation") }
        #expect(childMessage?.contains("└") == true)

        // 부모 span은 시작 표시
        let parentMessage = loggedMessages.first { $0.contains("parent_operation") }
        #expect(parentMessage?.hasPrefix("▶ ") == true)
    }
}

// MARK: - Test Helpers

/// 테스트용 인메모리 Destination
private actor InMemoryTestDestination: TraceDestination {
    let identifier: String = "InMemoryTestDestination"
    var minLevel: TraceLevel = .verbose
    var isEnabled: Bool = true
    private let onMessage: (TraceMessage) -> Void
    
    init(onMessage: @escaping (TraceMessage) -> Void) {
        self.onMessage = onMessage
    }
    
    func log(_ message: TraceMessage) async {
        onMessage(message)
    }
    
    func flush(_ messages: [TraceMessage]) async {
        for message in messages {
            onMessage(message)
        }
    }
}
