// AnalyticsRealtimeDemoViewModel.swift
// TraceKitDemo
//
// Created by jimmy on 2026-01-22.

import Foundation
import TraceKit

/// Analytics Realtime 데모의 이벤트 전송 이력
struct AnalyticsEventRecord: Identifiable {
    let id = UUID()
    let timestamp: Date
    let eventName: String
    let level: TraceLevel
    let category: String
    let message: String
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

/// Analytics Realtime Demo ViewModel
///
/// Firebase Analytics Realtime에서 즉시 확인 가능한 이벤트를 전송합니다.
/// trace_error, trace_fatal 이벤트를 실시간으로 생성하여
/// Firebase Console에서 1~2초 내 확인할 수 있습니다.
@MainActor
final class AnalyticsRealtimeDemoViewModel: ObservableObject {
    @Published var eventHistory: [AnalyticsEventRecord] = []
    @Published var userId: String = ""
    @Published var userPlan: String = ""
    @Published var isApplyingContext: Bool = false
    @Published var lastAppliedUserId: String?
    @Published var lastAppliedPlan: String?
    
    /// 네트워크 에러 시나리오 전송
    func sendNetworkError() {
        let message = "API timeout after 30 seconds"
        
        TraceKit.error(
            message,
            category: "Network",
            metadata: [
                "endpoint": AnyCodable("/api/v1/users/profile"),
                "method": AnyCodable("GET"),
                "timeout": AnyCodable(30.0),
                "retryCount": AnyCodable(3)
            ]
        )
        
        addEventToHistory(
            eventName: "trace_error",
            level: .error,
            category: "Network",
            message: message
        )
    }
    
    /// 결제 실패 시나리오 전송
    func sendPaymentFailure() {
        let message = "Payment gateway connection failed"
        
        TraceKit.error(
            message,
            category: "Payment",
            metadata: [
                "orderId": AnyCodable("ORD-2026-001234"),
                "amount": AnyCodable(59800),
                "paymentMethod": AnyCodable("card"),
                "errorCode": AnyCodable("GATEWAY_TIMEOUT")
            ]
        )
        
        addEventToHistory(
            eventName: "trace_error",
            level: .error,
            category: "Payment",
            message: message
        )
    }
    
    /// 크래시 발생 시나리오 전송
    func sendFatalCrash() {
        let message = "Database connection lost"
        
        TraceKit.fatal(
            message,
            category: "Database",
            metadata: [
                "connectionPool": AnyCodable("main"),
                "activeConnections": AnyCodable(0),
                "lastHeartbeat": AnyCodable(Date().timeIntervalSince1970 - 120)
            ]
        )
        
        addEventToHistory(
            eventName: "trace_fatal",
            level: .fatal,
            category: "Database",
            message: message
        )
    }
    
    /// 사용자 로그아웃 에러 시나리오 전송
    func sendLogoutError() {
        let message = "Token invalidation failed"
        
        TraceKit.error(
            message,
            category: "Auth",
            metadata: [
                "tokenType": AnyCodable("refresh_token"),
                "reason": AnyCodable("server_unreachable"),
                "willRetry": AnyCodable(true)
            ]
        )
        
        addEventToHistory(
            eventName: "trace_error",
            level: .error,
            category: "Auth",
            message: message
        )
    }
    
    /// User Context 적용
    func applyUserContext() async {
        guard !userId.isEmpty || !userPlan.isEmpty else {
            return
        }
        
        isApplyingContext = true
        defer { isApplyingContext = false }
        
        // DefaultUserContextProvider 가져오기
        let contextProvider = await DefaultUserContextProvider(environment: .debug)
        
        // User ID 설정
        if !userId.isEmpty {
            await contextProvider.setUserId(userId)
            lastAppliedUserId = userId
        }
        
        // User Plan 설정
        if !userPlan.isEmpty {
            await contextProvider.setAttribute(key: "plan", value: AnyCodable(userPlan))
            lastAppliedPlan = userPlan
        }
        
        // TraceKit에 provider 설정
        await TraceKit.async.setContextProvider(contextProvider)
        
        // 설정 확인용 로그
        TraceKit.info(
            "User Context updated",
            category: "Analytics",
            metadata: [
                "userId": AnyCodable(userId),
                "plan": AnyCodable(userPlan)
            ]
        )
    }
    
    /// 이벤트 히스토리에 추가
    private func addEventToHistory(
        eventName: String,
        level: TraceLevel,
        category: String,
        message: String
    ) {
        let record = AnalyticsEventRecord(
            timestamp: Date(),
            eventName: eventName,
            level: level,
            category: category,
            message: message
        )
        
        eventHistory.insert(record, at: 0)
        
        // 최대 20개까지만 유지
        if eventHistory.count > 20 {
            eventHistory = Array(eventHistory.prefix(20))
        }
    }
    
    /// 히스토리 초기화
    func clearHistory() {
        eventHistory.removeAll()
    }
}
