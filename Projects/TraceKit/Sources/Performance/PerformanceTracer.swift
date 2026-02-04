// PerformanceTracer.swift
// TraceKit
//
// Created by jimmy on 2025-12-15.

import Foundation

/// 성능 측정 추적기
/// - Note: 구간별 성능 측정 및 자동 로깅
public actor PerformanceTracer {
    /// 완료된 자식 span 정보
    private struct CompletedChildSpan {
        let span: TraceSpan
        let metadata: [String: AnyCodable]
    }

    /// 활성화된 span 목록
    private var activeSpans: [UUID: TraceSpan] = [:]

    /// 완료된 자식 span들 (부모 ID로 그룹화)
    private var completedChildSpans: [UUID: [CompletedChildSpan]] = [:]

    /// 로거 참조 (weak 대신 클로저 사용)
    private var logHandler: (@Sendable (TraceLevel, String, String, [String: AnyCodable]) async -> Void)?

    /// 카테고리
    private let category: String

    public init(
        category: String = "Performance",
        logHandler: (@Sendable (TraceLevel, String, String, [String: AnyCodable]) async -> Void)? = nil
    ) {
        self.category = category
        self.logHandler = logHandler
    }

    /// 로그 핸들러 설정
    /// - Parameter handler: 로그를 처리할 클로저
    /// - Note: TraceKit의 로그 파이프라인과 연결할 때 사용
    public func setLogHandler(_ handler: (@Sendable (TraceLevel, String, String, [String: AnyCodable]) async -> Void)?) {
        logHandler = handler
    }

    /// Span 시작
    /// - Parameters:
    ///   - name: Span 이름
    ///   - parentId: 부모 Span ID (중첩 시)
    /// - Returns: 생성된 Span ID
    public func startSpan(name: String, parentId: UUID? = nil) -> UUID {
        let span = TraceSpan(
            name: name,
            category: category,
            parentId: parentId
        )

        activeSpans[span.id] = span
        return span.id
    }

    /// Span 종료
    /// - Parameters:
    ///   - id: Span ID
    ///   - metadata: 추가 메타데이터
    /// - Returns: 완료된 Span (없으면 nil)
    @discardableResult
    public func endSpan(id: UUID, metadata: [String: AnyCodable] = [:]) async -> TraceSpan? {
        guard let span = activeSpans.removeValue(forKey: id) else {
            return nil
        }

        let completedSpan = span.ended(metadata: metadata)

        // 자동 로깅
        if let logHandler = logHandler, let durationMs = completedSpan.durationMs {
            if let parentId = completedSpan.parentId {
                // 자식 span: 저장만 하고 로그 출력하지 않음
                let childInfo = CompletedChildSpan(span: completedSpan, metadata: metadata)
                if completedChildSpans[parentId] == nil {
                    completedChildSpans[parentId] = []
                }
                completedChildSpans[parentId]?.append(childInfo)
            } else {
                // 부모 span: 먼저 부모 로그 출력
                let prefix = "▶ "
                let message = "\(prefix)[\(completedSpan.name)] completed in \(String(format: "%.2f", durationMs))ms"
                await logHandler(.debug, message, category, metadata)

                // 그 다음 자식 로그들 출력 (시간 순서대로)
                if let children = completedChildSpans[completedSpan.id] {
                    for child in children {
                        if let childDuration = child.span.durationMs {
                            let childPrefix = "  └ "
                            let childMessage = "\(childPrefix)[\(child.span.name)] completed in \(String(format: "%.2f", childDuration))ms"
                            await logHandler(.debug, childMessage, category, child.metadata)
                        }
                    }
                    completedChildSpans.removeValue(forKey: completedSpan.id)
                }
            }
        }

        return completedSpan
    }

    /// 측정 블록 실행
    /// - Parameters:
    ///   - name: Span 이름
    ///   - parentId: 부모 Span ID (중첩 시)
    ///   - operation: 측정할 작업
    /// - Returns: 작업 결과
    public func measure<T: Sendable>(
        name: String,
        parentId: UUID? = nil,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        let spanId = startSpan(name: name, parentId: parentId)

        do {
            let result = try await operation()
            await endSpan(id: spanId) // 성공 시 메타데이터 없음
            return result
        } catch {
            await endSpan(id: spanId, metadata: [
                "error": AnyCodable(error.localizedDescription),
            ])
            throw error
        }
    }

    /// 동기 측정 블록 실행
    /// - Parameters:
    ///   - name: Span 이름
    ///   - parentId: 부모 Span ID (중첩 시)
    ///   - operation: 측정할 작업
    /// - Returns: 작업 결과
    public func measureSync<T>(
        name: String,
        parentId: UUID? = nil,
        operation: () throws -> T
    ) async rethrows -> T {
        let spanId = startSpan(name: name, parentId: parentId)

        do {
            let result = try operation()
            await endSpan(id: spanId) // 성공 시 메타데이터 없음
            return result
        } catch {
            await endSpan(id: spanId, metadata: [
                "error": AnyCodable(error.localizedDescription),
            ])
            throw error
        }
    }

    /// 활성 Span 수
    public var activeSpanCount: Int {
        activeSpans.count
    }

    /// 모든 활성 Span 취소
    public func cancelAllSpans() {
        activeSpans.removeAll()
        completedChildSpans.removeAll()
    }
}
