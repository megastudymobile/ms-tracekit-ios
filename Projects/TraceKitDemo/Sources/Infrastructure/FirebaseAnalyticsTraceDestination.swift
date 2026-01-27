// FirebaseAnalyticsTraceDestination.swift
// TraceKitDemo
//
// Created by jimmy on 2026-01-22.

import Foundation
import TraceKit
import FirebaseAnalytics

/// Firebase Analytics와 연동하는 TraceDestination
///
/// TraceKit의 특정 레벨 로그를 Firebase Analytics 이벤트로 전송합니다.
/// 에러 패턴 분석, 사용자 행동 추적, BigQuery 연동에 활용됩니다.
///
/// ## 전송 정책
/// - `.error`: `trace_error` 이벤트로 전송
/// - `.critical`: `trace_critical` 이벤트로 전송
/// - 나머지 레벨: 전송하지 않음 (과도한 이벤트 방지)
///
/// ## Analytics 이벤트 파라미터
/// - `level`: 로그 레벨 (error, critical)
/// - `category`: 로그 카테고리
/// - `message`: 로그 메시지 (최대 100자)
/// - `timestamp`: ISO8601 타임스탬프
///
/// ## 사용 예시
/// ```swift
/// let destination = FirebaseAnalyticsTraceDestination()
/// await TraceKitBuilder()
///     .addDestination(destination)
///     .buildAsShared()
/// ```
actor FirebaseAnalyticsTraceDestination: TraceDestination {
    private let maxMessageLength = 100
    
    // MARK: - TraceDestination
    
    nonisolated var identifier: String { "firebase.analytics" }
    var minLevel: TraceLevel = .error
    var isEnabled: Bool = true
    
    /// TraceMessage를 Analytics 이벤트로 전송
    ///
    /// `.error`, `.critical` 레벨만 전송하여 이벤트 할당량을 절약합니다.
    ///
    /// - Parameter message: 기록할 TraceMessage
    func log(_ message: TraceMessage) async {
        guard shouldLog(message) else { return }
        
        let eventName = eventName(for: message.level)
        let parameters = buildParameters(from: message)
        
        Analytics.logEvent(eventName, parameters: parameters)
        
        updateUserProperties(message.userContext)
    }
    
    /// TraceLevel에 대응하는 Analytics 이벤트 이름 반환
    private func eventName(for level: TraceLevel) -> String {
        switch level {
        case .error: return "trace_error"
        case .fatal: return "trace_fatal"
        default: return "trace_event"
        }
    }
    
    /// TraceMessage에서 Analytics 파라미터 추출
    private func buildParameters(from message: TraceMessage) -> [String: Any] {
        var parameters: [String: Any] = [
            "level": message.level.name,
            "category": message.category,
            "timestamp": ISO8601DateFormatter().string(from: message.timestamp)
        ]
        
        let truncatedMessage = truncateMessage(message.message)
        parameters["message"] = truncatedMessage
        
        return parameters
    }
    
    /// 메시지를 최대 길이로 제한
    ///
    /// Firebase Analytics는 파라미터 값 길이에 제한이 있습니다.
    private func truncateMessage(_ message: String) -> String {
        if message.count <= maxMessageLength {
            return message
        }
        
        let truncated = String(message.prefix(maxMessageLength - 3))
        return "\(truncated)..."
    }
    
    /// 사용자 컨텍스트를 Analytics User Properties로 동기화
    private func updateUserProperties(_ context: UserContext?) {
        guard let context = context else { return }
        
        if let userId = context.userId {
            Analytics.setUserID(userId)
        }
        
        for (key, value) in context.customAttributes {
            Analytics.setUserProperty(
                String(describing: value.value),
                forName: sanitizePropertyName(key)
            )
        }
    }
    
    /// User Property 이름을 Firebase 규칙에 맞게 정제
    ///
    /// Firebase Analytics User Property 이름 규칙:
    /// - 24자 이내
    /// - 알파벳으로 시작
    /// - 알파벳, 숫자, 언더스코어만 허용
    private func sanitizePropertyName(_ name: String) -> String {
        let sanitized = name
            .prefix(24)
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
        
        return String(sanitized)
    }
}
