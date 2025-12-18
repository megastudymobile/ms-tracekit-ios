// AnalyticsTraceDestination.swift
// TraceKitFirebase
//
// Created by jimmy on 2025-12-15.

import FirebaseAnalytics
import Foundation
import TraceKit

/// Firebase Analytics 로그 목적지
/// - Note: 특정 레벨/카테고리의 로그를 Analytics 이벤트로 전송
public actor AnalyticsTraceDestination: TraceDestination {
    public let identifier: String = "analytics"

    public var minLevel: TraceLevel
    public var isEnabled: Bool

    /// 이벤트로 전송할 카테고리
    private let eventCategories: Set<String>

    /// 이벤트 이름 프리픽스
    private let eventPrefix: String

    public init(
        minLevel: TraceLevel = .info,
        isEnabled: Bool = true,
        eventCategories: Set<String> = ["Analytics", "UserAction", "Screen"],
        eventPrefix: String = "log_"
    ) {
        self.minLevel = minLevel
        self.isEnabled = isEnabled
        self.eventCategories = eventCategories
        self.eventPrefix = eventPrefix
    }

    public func log(_ message: TraceMessage) async {
        guard shouldLog(message) else { return }

        // 특정 카테고리만 Analytics로 전송
        guard eventCategories.contains(message.category) else { return }

        // 이벤트 이름 생성 (Firebase 규칙에 맞게)
        let eventName = sanitizeEventName("\(eventPrefix)\(message.category.lowercased())")

        // 파라미터 준비
        var parameters: [String: Any] = [
            "level": message.level.name,
            "message": String(message.message.prefix(100)) // 100자 제한
        ]

        // 메타데이터 추가 (Analytics 파라미터 제한 고려)
        if let metadata = message.metadata {
            for (key, value) in metadata.prefix(20) { // 최대 25개 파라미터
                let sanitizedKey = sanitizeParameterName(key)
                parameters[sanitizedKey] = String(describing: value.value).prefix(100)
            }
        }

        // 사용자 컨텍스트
        if let userContext = message.userContext {
            if let userId = userContext.userId {
                Analytics.setUserID(userId)
            }
            parameters["app_version"] = userContext.appVersion
        }

        // 이벤트 전송
        Analytics.logEvent(eventName, parameters: parameters)
    }

    // MARK: - Private

    /// Firebase 이벤트 이름 규칙에 맞게 정제
    private func sanitizeEventName(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        // 숫자로 시작하면 안 됨
        if let first = sanitized.first, first.isNumber {
            sanitized = "_" + sanitized
        }

        // 40자 제한
        return String(sanitized.prefix(40))
    }

    /// Firebase 파라미터 이름 규칙에 맞게 정제
    private func sanitizeParameterName(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        if let first = sanitized.first, first.isNumber {
            sanitized = "_" + sanitized
        }

        return String(sanitized.prefix(40))
    }
}

// MARK: - User Properties

public extension AnalyticsTraceDestination {
    /// 사용자 속성 설정
    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    /// 사용자 ID 설정
    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }

    /// 화면 이름 설정
    func setScreenName(_ screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
    }
}
