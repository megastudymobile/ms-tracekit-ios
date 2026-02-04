// FirebasePerformanceTraceDestination.swift
// TraceKitDemo
//
// Created by jimmy on 2026-02-04.

import FirebasePerformance
import Foundation
import TraceKit

/// Firebase Performance와 연동하는 TraceDestination
///
/// TraceKit의 PerformanceTracer span 완료 로그를 Firebase Performance Trace로 자동 전송합니다.
/// 성능 데이터를 Firebase Console에서 시각화하고 분석할 수 있습니다.
///
/// ## 전송 정책
/// - Category가 "Performance"인 로그만 처리
/// - Span 완료 메시지(completed in X ms)를 감지하여 Firebase Trace 생성
/// - 커스텀 메트릭과 속성 자동 추출
///
/// ## Firebase Performance 이벤트
/// - Trace Name: span 이름 (sanitized)
/// - 메트릭: duration_ms, 기타 숫자형 메타데이터
/// - 속성: 문자열 메타데이터 (최대 40자)
///
/// ## 사용 예시
/// ```swift
/// let destination = FirebasePerformanceTraceDestination()
/// await TraceKitBuilder()
///     .addDestination(destination)
///     .buildAsShared()
/// ```
actor FirebasePerformanceTraceDestination: TraceDestination {
    private let maxTraceNameLength = 100
    private let maxAttributeLength = 40

    // MARK: - TraceDestination

    nonisolated var identifier: String { "firebase.performance" }
    var minLevel: TraceLevel = .debug
    var isEnabled: Bool = true

    /// TraceMessage를 Firebase Performance Trace로 전송
    ///
    /// Performance 카테고리이고 span 완료 메시지인 경우에만 처리합니다.
    ///
    /// - Parameter message: 기록할 TraceMessage
    func log(_ message: TraceMessage) async {
        guard shouldLog(message) else { return }

        // Performance 카테고리만 처리
        guard message.category == "Performance" else { return }

        // Span 완료 메시지 감지 (PerformanceTracer가 생성하는 메시지 패턴)
        guard message.message.contains("completed in") else { return }

        // Span 이름 추출: "[span_name] completed in X.XXms" 패턴
        guard let spanName = extractSpanName(from: message.message) else { return }

        // Firebase Trace 생성 및 전송
        await sendToFirebasePerformance(
            name: spanName,
            metadata: message.metadata ?? [:]
        )
    }

    /// 메시지에서 span 이름 추출
    ///
    /// 패턴: "[span_name] completed in X.XXms" 또는 "└ [span_name] completed in X.XXms"
    private func extractSpanName(from message: String) -> String? {
        // 들여쓰기 제거 (자식 span의 경우 "└ " 접두사)
        let trimmedMessage = message.trimmingCharacters(in: .whitespaces)
        let messageWithoutPrefix = trimmedMessage.hasPrefix("└ ")
            ? String(trimmedMessage.dropFirst(2))
            : trimmedMessage

        guard messageWithoutPrefix.hasPrefix("[") else { return nil }

        guard let endIndex = messageWithoutPrefix.firstIndex(of: "]") else { return nil }

        let startIndex = messageWithoutPrefix.index(after: messageWithoutPrefix.startIndex)
        let spanName = String(messageWithoutPrefix[startIndex ..< endIndex])

        return spanName.isEmpty ? nil : spanName
    }

    /// Firebase Performance Trace로 전송
    private func sendToFirebasePerformance(
        name: String,
        metadata: [String: AnyCodable]
    ) async {
        let sanitizedName = sanitizeTraceName(name)

        guard let trace = Performance.startTrace(name: sanitizedName) else {
            return
        }

        // 메트릭 추가
        addMetrics(to: trace, from: metadata)

        // 속성 추가
        addAttributes(to: trace, from: metadata)

        // Trace 전송
        trace.stop()
    }

    /// Firebase Performance Trace 이름 규칙에 맞게 정제
    ///
    /// Firebase Performance Trace 이름 규칙:
    /// - 100자 이내
    /// - 알파벳으로 시작
    /// - 언더스코어로 단어 구분
    private func sanitizeTraceName(_ name: String) -> String {
        let sanitized = name
            .prefix(maxTraceNameLength)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)

        if sanitized.first?.isLetter == false {
            return "trace_\(sanitized)"
        }

        return String(sanitized)
    }

    /// 메타데이터에서 메트릭 추출 및 추가
    private func addMetrics(to trace: Trace, from metadata: [String: AnyCodable]) {
        // duration_ms는 PerformanceTracer가 자동으로 추가
        if let durationMs = metadata["durationMs"],
           let value = extractNumericValue(durationMs)
        {
            trace.setValue(value, forMetric: "duration_ms")
        }

        // success 메트릭: error가 없으면 성공(1), 있으면 실패(0)
        let hasError = metadata.keys.contains("error")
        let successValue: Int64 = hasError ? 0 : 1
        trace.setValue(successValue, forMetric: "success")
    }

    /// 메타데이터에서 속성 추출 및 추가
    ///
    /// Firebase Performance는 최대 5개의 속성만 허용하므로 핵심 정보만 전송합니다.
    /// - parentId: 부모 span ID (계층 구조 파악용)
    private func addAttributes(to trace: Trace, from metadata: [String: AnyCodable]) {
        // 우선순위 1: parentId (부모-자식 관계)
        if let parentId = metadata["parentId"] {
            let stringValue = String(describing: parentId.value)
            trace.setValue(stringValue, forAttribute: "parent_id")
        }

        // 나머지 메타데이터는 Firebase 속성 제한(5개) 때문에 제외
        // spanId, startTimeNanos, endTimeNanos, name, category 등은
        // Firebase Performance의 기본 trace 정보로 충분히 식별 가능
    }

    /// 메트릭 이름 정제
    private func sanitizeMetricName(_ name: String) -> String {
        let sanitized = name
            .prefix(maxTraceNameLength)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)

        return String(sanitized)
    }

    /// 속성 이름 정제
    ///
    /// Firebase Performance 속성 이름 규칙:
    /// - 40자 이내
    /// - 알파벳, 숫자, 언더스코어만 허용
    private func sanitizeAttributeName(_ name: String) -> String {
        let sanitized = name
            .prefix(maxAttributeLength)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)

        return String(sanitized)
    }

    /// AnyCodable 값에서 숫자 추출
    private func extractNumericValue(_ value: AnyCodable) -> Int64? {
        if let intValue = value.value as? Int {
            return Int64(intValue)
        }

        if let int64Value = value.value as? Int64 {
            return int64Value
        }

        if let doubleValue = value.value as? Double {
            return Int64(doubleValue)
        }

        if let floatValue = value.value as? Float {
            return Int64(floatValue)
        }

        return nil
    }
}
