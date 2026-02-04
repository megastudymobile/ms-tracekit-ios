// PerformanceViewModel.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-15.

import Foundation
import TraceKit

@MainActor
final class PerformanceViewModel: ObservableObject {
    struct MeasurementResult: Identifiable {
        let id = UUID()
        let name: String
        let duration: TimeInterval
        let timestamp: Date
    }

    @Published var results: [MeasurementResult] = []
    @Published var isRunning: Bool = false
    @Published var currentOperation: String = ""

    // MARK: - Measure Demo

    func runMeasureDemo() async {
        isRunning = true
        currentOperation = "measure() 시연 중..."

        let startTime = Date()

        // measure() API 사용 - 자동으로 span 시작/종료 및 Firebase 전송
        _ = await TraceKit.async.measure(name: "데이터_로딩_시뮬레이션") {
            await simulateNetworkRequest(delay: 1.5)
        }

        let duration = Date().timeIntervalSince(startTime)
        let result = MeasurementResult(
            name: "데이터 로딩 시뮬레이션",
            duration: duration,
            timestamp: Date()
        )
        results.insert(result, at: 0)

        isRunning = false
        currentOperation = ""
    }

    // MARK: - Span Demo

    func runSpanDemo() async {
        isRunning = true
        currentOperation = "Span 시연 중..."

        let startTime = Date()

        // Parent span
        let parentId = await TraceKit.async.startSpan(name: "전체 프로세스")

        // Child span 1
        let child1Id = await TraceKit.async.startSpan(name: "데이터 페칭", parentId: parentId)
        await simulateNetworkRequest(delay: 0.5)
        await TraceKit.async.endSpan(id: child1Id)

        let result1 = MeasurementResult(
            name: "  └ 데이터 페칭",
            duration: 0.5,
            timestamp: Date()
        )
        results.insert(result1, at: 0)

        // Child span 2
        let child2Id = await TraceKit.async.startSpan(name: "데이터 파싱", parentId: parentId)
        await simulateProcessing(delay: 0.3)
        await TraceKit.async.endSpan(id: child2Id)

        let result2 = MeasurementResult(
            name: "  └ 데이터 파싱",
            duration: 0.3,
            timestamp: Date()
        )
        results.insert(result2, at: 0)

        // Child span 3
        let child3Id = await TraceKit.async.startSpan(name: "UI 업데이트", parentId: parentId)
        await simulateUIUpdate(delay: 0.2)
        await TraceKit.async.endSpan(id: child3Id)

        let result3 = MeasurementResult(
            name: "  └ UI 업데이트",
            duration: 0.2,
            timestamp: Date()
        )
        results.insert(result3, at: 0)

        // End parent
        await TraceKit.async.endSpan(id: parentId)

        let totalDuration = Date().timeIntervalSince(startTime)
        let parentResult = MeasurementResult(
            name: "전체 프로세스",
            duration: totalDuration,
            timestamp: Date()
        )
        results.insert(parentResult, at: 0)

        isRunning = false
        currentOperation = ""
    }

    // MARK: - Heavy Operation Demo

    func runHeavyOperationDemo() async {
        isRunning = true
        currentOperation = "무거운 작업 시연 중..."

        let startTime = Date()

        TraceKit.info("무거운 작업 시작", category: "Performance")

        // 전체 작업을 span으로 감싸기
        let parentSpanId = await TraceKit.async.startSpan(name: "병렬_작업_전체")

        // 각 서브태스크도 span으로 추적 (부모 span 연결)
        await withTaskGroup(of: Void.self) { group in
            for i in 1 ... 5 {
                group.addTask {
                    _ = await TraceKit.async.measure(name: "서브태스크_\(i)", parentId: parentSpanId) {
                        await self.simulateProcessing(delay: 0.3)
                    }
                }
            }
        }

        await TraceKit.async.endSpan(id: parentSpanId)

        let duration = Date().timeIntervalSince(startTime)
        TraceKit.info("무거운 작업 완료: \(String(format: "%.2f", duration))초", category: "Performance")

        let result = MeasurementResult(
            name: "병렬 작업 (5개 서브태스크)",
            duration: duration,
            timestamp: Date()
        )
        results.insert(result, at: 0)

        isRunning = false
        currentOperation = ""
    }

    // MARK: - Complex Span Demo

    func runSpanWithFirebaseDemo() async {
        isRunning = true
        currentOperation = "복합 Span 자동 전송 시연 중..."

        let startTime = Date()

        // Parent span
        let parentId = await TraceKit.async.tracer.startSpan(name: "user_data_fetch")

        // Child span 1: API 호출
        let apiSpanId = await TraceKit.async.tracer.startSpan(
            name: "api_request",
            parentId: parentId
        )
        await simulateNetworkRequest(delay: 0.8)
        await TraceKit.async.tracer.endSpan(id: apiSpanId)

        // Child span 2: 데이터 변환
        let transformSpanId = await TraceKit.async.tracer.startSpan(
            name: "data_transform",
            parentId: parentId
        )
        await simulateProcessing(delay: 0.4)
        await TraceKit.async.tracer.endSpan(id: transformSpanId)

        // Child span 3: 캐시 저장
        let cacheSpanId = await TraceKit.async.tracer.startSpan(
            name: "cache_save",
            parentId: parentId
        )
        await simulateProcessing(delay: 0.3)
        await TraceKit.async.tracer.endSpan(id: cacheSpanId)

        // Parent span 종료 - 모든 span이 자동으로 Firebase에 전송됨
        await TraceKit.async.tracer.endSpan(id: parentId)

        let duration = Date().timeIntervalSince(startTime)

        TraceKit.info(
            "복합 Span 자동 전송 완료 (parent + 3 children)",
            category: "Performance"
        )

        let result = MeasurementResult(
            name: "복합 Span 자동 추적",
            duration: duration,
            timestamp: Date()
        )
        results.insert(result, at: 0)

        isRunning = false
        currentOperation = ""
    }

    // MARK: - Clear

    func clearResults() {
        results.removeAll()
    }

    // MARK: - Simulation Helpers

    private func simulateNetworkRequest(delay: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private func simulateProcessing(delay: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private func simulateUIUpdate(delay: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}
