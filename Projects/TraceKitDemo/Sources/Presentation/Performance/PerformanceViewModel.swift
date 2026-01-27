// PerformanceViewModel.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-15.

import Foundation
import TraceKit
import FirebasePerformance

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

        let spanId = await TraceKit.async.tracer.startSpan(name: "데이터 로딩 시뮬레이션")

        await simulateNetworkRequest(delay: 1.5)

        let completedSpan = await TraceKit.async.tracer.endSpan(id: spanId)

        let duration = completedSpan?.durationMs.map { $0 / 1000.0 } ?? 1.5
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

        // Simulate heavy computation
        await withTaskGroup(of: Void.self) { group in
            for i in 1 ... 5 {
                group.addTask {
                    await self.simulateProcessing(delay: 0.3)
                    TraceKit.debug("서브태스크 \(i) 완료", category: "Performance")
                }
            }
        }

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
    
    // MARK: - Firebase Performance Demo
    
    func runFirebasePerformanceDemo() async {
        isRunning = true
        currentOperation = "Firebase Performance 시연 중..."
        
        do {
            let startTime = Date()
            
            // FirebasePerformanceHelper를 사용한 성능 추적
            let data = try await FirebasePerformanceHelper.trace(
                name: "firebase_demo_operation"
            ) {
                await simulateNetworkRequest(delay: 1.0)
                return "Demo Data"
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            TraceKit.info(
                "Firebase Performance 데이터 전송 완료: \(data)",
                category: "Performance"
            )
            
            let result = MeasurementResult(
                name: "Firebase Performance 추적",
                duration: duration,
                timestamp: Date()
            )
            results.insert(result, at: 0)
            
        } catch {
            TraceKit.error(
                "Firebase Performance 실패: \(error.localizedDescription)",
                category: "Performance"
            )
        }
        
        isRunning = false
        currentOperation = ""
    }
    
    func runSpanWithFirebaseDemo() async {
        isRunning = true
        currentOperation = "TraceSpan + Firebase Performance 시연 중..."
        
        let startTime = Date()
        
        // TraceKit의 TraceSpan 사용
        let spanId = await TraceKit.async.tracer.startSpan(name: "user_data_fetch")
        
        // 네트워크 요청 시뮬레이션
        await simulateNetworkRequest(delay: 1.5)
        
        // Span 종료
        if let span = await TraceKit.async.tracer.endSpan(id: spanId) {
            // Firebase Performance로 전송
            await span.sendToFirebasePerformance()
            
            let duration = Date().timeIntervalSince(startTime)
            
            TraceKit.info(
                "TraceSpan + Firebase Performance 기록 완료",
                category: "Performance"
            )
            
            let result = MeasurementResult(
                name: "TraceSpan + Firebase",
                duration: duration,
                timestamp: Date()
            )
            results.insert(result, at: 0)
        }
        
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
