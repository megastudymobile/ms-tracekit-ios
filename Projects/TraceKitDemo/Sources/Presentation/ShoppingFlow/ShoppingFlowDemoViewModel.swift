// ShoppingFlowDemoViewModel.swift
// TraceKitDemo
//
// Created by jimmy on 2026-01-22.

import Foundation
import TraceKit

/// 쇼핑 플로우 단계
enum ShoppingStep: String, CaseIterable {
    case idle = "대기 중"
    case browsing = "상품 탐색"
    case addingToCart = "장바구니 추가"
    case viewingCart = "장바구니 확인"
    case checkout = "결제 진행"
    case completed = "완료"
    case failed = "실패"
    
    var icon: String {
        switch self {
        case .idle: return "circle"
        case .browsing: return "magnifyingglass"
        case .addingToCart: return "cart.badge.plus"
        case .viewingCart: return "cart"
        case .checkout: return "creditcard"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

/// Firebase 서비스 전송 상태
struct FirebaseServiceStatus {
    var analyticsEventCount: Int = 0
    var crashlyticsBreadcrumbCount: Int = 0
    var performanceTraceCompleted: Bool = false
    var lastEvent: String = ""
    var traceDuration: Double?
}

/// Shopping Flow Demo ViewModel
///
/// 실무 쇼핑 앱 플로우를 시뮬레이션하며
/// Firebase 4대 서비스(Analytics, Crashlytics, Performance, Remote Config)
/// 연동을 실시간으로 보여줍니다.
@MainActor
final class ShoppingFlowDemoViewModel: ObservableObject {
    @Published var currentStep: ShoppingStep = .idle
    @Published var firebaseStatus = FirebaseServiceStatus()
    @Published var isRunning: Bool = false
    @Published var flowType: FlowType = .success
    
    enum FlowType {
        case success
        case failure
        
        var displayName: String {
            switch self {
            case .success: return "정상 플로우"
            case .failure: return "에러 플로우"
            }
        }
    }
    
    /// 정상 플로우 실행
    func startSuccessFlow() async {
        guard !isRunning else { return }
        
        isRunning = true
        flowType = .success
        resetStatus()
        
        // TraceKit Performance Span 시작
        let checkoutSpanId = await TraceKit.async.startSpan(name: "shopping_checkout_flow")
        let startTime = Date()
        
        // 1. 상품 탐색
        currentStep = .browsing
        await logStep("사용자가 상품을 탐색하고 있습니다", category: "Shopping")
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // 2. 장바구니 추가
        currentStep = .addingToCart
        await logStep("상품을 장바구니에 추가했습니다", category: "Cart")
        firebaseStatus.crashlyticsBreadcrumbCount += 1
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 3. 장바구니 확인
        currentStep = .viewingCart
        await logStep("장바구니 화면을 열었습니다", category: "Cart")
        firebaseStatus.crashlyticsBreadcrumbCount += 1
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 4. 결제 진행
        currentStep = .checkout
        await logStep("결제 프로세스를 시작했습니다", category: "Payment")
        firebaseStatus.crashlyticsBreadcrumbCount += 1
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // 5. 결제 성공
        currentStep = .completed
        TraceKit.info(
            "결제가 성공적으로 완료되었습니다",
            category: "Payment",
            metadata: [
                "orderId": AnyCodable("ORD-2026-\(Int.random(in: 10000...99999))"),
                "amount": AnyCodable(59800),
                "paymentMethod": AnyCodable("card")
            ]
        )
        firebaseStatus.lastEvent = "결제 완료"
        firebaseStatus.crashlyticsBreadcrumbCount += 1
        
        // Performance Trace 종료
        if let span = await TraceKit.async.tracer.endSpan(id: checkoutSpanId) {
            await span.sendToFirebasePerformance()
            firebaseStatus.performanceTraceCompleted = true
            firebaseStatus.traceDuration = Date().timeIntervalSince(startTime)
        }
        
        isRunning = false
    }
    
    /// 에러 플로우 실행
    func startFailureFlow() async {
        guard !isRunning else { return }
        
        isRunning = true
        flowType = .failure
        resetStatus()
        
        // TraceKit Performance Span 시작
        let checkoutSpanId = await TraceKit.async.startSpan(name: "shopping_checkout_flow_failed")
        let startTime = Date()
        
        // 1. 상품 탐색
        currentStep = .browsing
        await logStep("사용자가 상품을 탐색하고 있습니다", category: "Shopping")
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // 2. 장바구니 추가
        currentStep = .addingToCart
        await logStep("상품을 장바구니에 추가했습니다", category: "Cart")
        firebaseStatus.crashlyticsBreadcrumbCount += 1
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 3. 장바구니 확인
        currentStep = .viewingCart
        await logStep("장바구니 화면을 열었습니다", category: "Cart")
        firebaseStatus.crashlyticsBreadcrumbCount += 1
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 4. 결제 진행
        currentStep = .checkout
        TraceKit.warning(
            "카드 정보를 검증하고 있습니다",
            category: "Payment"
        )
        firebaseStatus.crashlyticsBreadcrumbCount += 1
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // 5. 결제 실패 (에러 발생)
        currentStep = .failed
        TraceKit.error(
            "결제 실패: 카드 한도 초과",
            category: "Payment",
            metadata: [
                "errorCode": AnyCodable("CARD_LIMIT_EXCEEDED"),
                "amount": AnyCodable(59800),
                "cardType": AnyCodable("credit"),
                "retryable": AnyCodable(true)
            ]
        )
        firebaseStatus.analyticsEventCount += 1
        firebaseStatus.lastEvent = "trace_error (결제 실패)"
        firebaseStatus.crashlyticsBreadcrumbCount += 1
        
        // Performance Trace 종료
        if let span = await TraceKit.async.tracer.endSpan(id: checkoutSpanId) {
            await span.sendToFirebasePerformance()
            firebaseStatus.performanceTraceCompleted = true
            firebaseStatus.traceDuration = Date().timeIntervalSince(startTime)
        }
        
        isRunning = false
    }
    
    /// 초기화
    func reset() {
        currentStep = .idle
        isRunning = false
        resetStatus()
    }
    
    /// Firebase 상태 초기화
    private func resetStatus() {
        firebaseStatus = FirebaseServiceStatus()
    }
    
    /// 단계별 로그
    private func logStep(_ message: String, category: String) async {
        TraceKit.info(message, category: category)
        firebaseStatus.crashlyticsBreadcrumbCount += 1
    }
    
    /// 진행률 계산
    var progress: Double {
        switch currentStep {
        case .idle: return 0.0
        case .browsing: return 0.2
        case .addingToCart: return 0.4
        case .viewingCart: return 0.6
        case .checkout: return 0.8
        case .completed, .failed: return 1.0
        }
    }
}
