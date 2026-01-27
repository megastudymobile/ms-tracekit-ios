// FirebaseCrashlyticsTraceDestination.swift
// TraceKitDemo
//
// Created by jimmy on 2026-01-22.

import Foundation
import TraceKit
import FirebaseCrashlytics

/// Firebase Crashlytics와 연동하는 TraceDestination
///
/// TraceKit의 로그를 Firebase Crashlytics Breadcrumb로 전송합니다.
/// 에러 레벨 이상의 로그는 명시적으로 에러로 기록됩니다.
///
/// ## 주요 기능
/// - `.debug`, `.info`, `.warning`: Breadcrumb로 기록
/// - `.error`, `.critical`: 명시적 에러 기록 + Breadcrumb
/// - 사용자 컨텍스트를 Crashlytics User ID/Custom Keys에 동기화
/// - 민감정보는 TraceKit의 Sanitizer를 통과한 메시지만 전송
///
/// ## 사용 예시
/// ```swift
/// let destination = FirebaseCrashlyticsTraceDestination()
/// await TraceKitBuilder()
///     .addDestination(destination)
///     .buildAsShared()
/// ```
actor FirebaseCrashlyticsTraceDestination: TraceDestination {
    private nonisolated let crashlytics = Crashlytics.crashlytics()
    
    // MARK: - TraceDestination
    
    nonisolated var identifier: String { "firebase.crashlytics" }
    var minLevel: TraceLevel = .debug
    var isEnabled: Bool = true
    
    /// TraceMessage를 Crashlytics에 기록
    ///
    /// - `.debug`, `.info`, `.warning`: Breadcrumb 형식으로 기록
    /// - `.error`, `.critical`: NSError로 변환하여 명시적 기록
    ///
    /// - Parameter message: 기록할 TraceMessage
    func log(_ message: TraceMessage) async {
        guard shouldLog(message) else { return }
        
        let breadcrumb = formatBreadcrumb(message)
        crashlytics.log(breadcrumb)
        
        if message.level >= .error {
            recordError(message)
        }
        
        updateUserContext(message.userContext)
    }
    
    /// Breadcrumb 형식으로 메시지 포맷
    private func formatBreadcrumb(_ message: TraceMessage) -> String {
        let components: [String] = [
            "[\(message.level.name)]",
            "[\(message.category)]",
            message.message
        ]
        
        return components.joined(separator: " ")
    }
    
    /// 에러 레벨 메시지를 명시적 에러로 기록
    private func recordError(_ message: TraceMessage) {
        let error = NSError(
            domain: "com.tracekit.TraceKitDemo",
            code: errorCode(for: message.level),
            userInfo: [
                NSLocalizedDescriptionKey: message.message,
                "category": message.category,
                "level": message.level.name,
                "timestamp": ISO8601DateFormatter().string(from: message.timestamp)
            ]
        )
        
        crashlytics.record(error: error)
        
        // 디버그 모드: 즉시 전송 (프로덕션에서는 자동 전송)
        #if DEBUG
        crashlytics.sendUnsentReports()
        print("🔥 [Crashlytics] 에러 리포트 즉시 전송: \(message.message)")
        #endif
    }
    
    /// TraceLevel에 대응하는 에러 코드 반환
    private func errorCode(for level: TraceLevel) -> Int {
        switch level {
        case .error: return 1000
        case .fatal: return 2000
        default: return 0
        }
    }
    
    /// 사용자 컨텍스트를 Crashlytics에 동기화
    private func updateUserContext(_ context: UserContext?) {
        guard let context = context else { return }
        
        if let userId = context.userId {
            crashlytics.setUserID(userId)
        }
        
        for (key, value) in context.customAttributes {
            crashlytics.setCustomValue(value.value, forKey: key)
        }
    }
}
