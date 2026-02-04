// LogGeneratorViewModel.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-15.

import Foundation
import TraceKit

@MainActor
final class LogGeneratorViewModel: ObservableObject {
    @Published var selectedCategory: String = "Default"
    @Published var customMessage: String = ""
    @Published var includeMetadata: Bool = false
    @Published var lastLoggedLevel: TraceLevel?

    let categories = ["Default", "Network", "Auth", "UI", "Database", "Analytics"]

    private var sampleMetadata: [String: AnyCodable] {
        [
            "userId": AnyCodable("user_12345"),
            "sessionId": AnyCodable(UUID().uuidString),
            "timestamp": AnyCodable(Date().timeIntervalSince1970),
        ]
    }
    
    // Note: sampleMetadata는 조건부 사용을 위해 기존 API 유지

    func log(level: TraceLevel) {
        let message = customMessage.isEmpty ? sampleMessage(for: level) : customMessage
        let metadata = includeMetadata ? sampleMetadata : nil

        TraceKit.log(
            level: level,
            message,
            category: selectedCategory,
            metadata: metadata
        )

        lastLoggedLevel = level

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.lastLoggedLevel = nil
        }
    }

    func logAllLevels() {
        Task {
            for level in TraceLevel.allCases {
                TraceKit.log(
                    level: level,
                    sampleMessage(for: level),
                    category: selectedCategory
                )
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    // MARK: - Network Logging Examples

    func logNetworkRequest() {
        let requestMetadata: [String: AnyCodable] = [
            "method": "GET",
            "url": "https://api.example.com/users/123",
            "headers": [
                "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIxMjM0NTYiLCJleHAiOjE3MzQyNTYwMDB9.mock_signature_here",
                "Content-Type": "application/json",
                "Accept": "application/json",
            ],
            "timeout": 30.0,
        ]

        TraceKit.debug(
            "API 요청 시작",
            category: "Network",
            metadata: requestMetadata
        )

        lastLoggedLevel = .debug
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.lastLoggedLevel = nil
        }
    }

    func logNetworkResponse() {
        let responseMetadata: [String: AnyCodable] = [
            "statusCode": 200,
            "url": "https://api.example.com/users/123",
            "duration": 0.234,
            "responseBody": [
                "id": 123,
                "name": "홍길동",
                "email": "hong@example.com",
                "createdAt": "2025-12-15T10:30:00Z",
            ],
            "headers": [
                "Content-Type": "application/json",
                "X-Request-Id": "req-abc123",
            ],
        ]

        TraceKit.info(
            "API 응답 성공",
            category: "Network",
            metadata: responseMetadata
        )

        lastLoggedLevel = .info
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.lastLoggedLevel = nil
        }
    }

    func logNetworkError() {
        let errorMetadata: [String: AnyCodable] = [
            "statusCode": 401,
            "url": "https://api.example.com/users/123",
            "duration": 0.156,
            "error": [
                "code": "UNAUTHORIZED",
                "message": "토큰이 만료되었습니다",
                "details": [
                    "expiredAt": "2025-12-15T09:00:00Z",
                    "tokenType": "access_token",
                ],
            ],
            "retryable": true,
            "retryCount": 0,
        ]

        TraceKit.error(
            "API 요청 실패: 인증 오류",
            category: "Network",
            metadata: errorMetadata
        )

        lastLoggedLevel = .error
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.lastLoggedLevel = nil
        }
    }

    func logNetworkFullCycle() {
        Task {
            // 1. Request (중첩된 dictionary는 기존 API 사용)
            TraceKit.debug(
                "API 요청 시작",
                category: "Network",
                metadata: [
                    "method": "POST",
                    "url": "https://api.example.com/orders",
                    "body": [
                        "productId": 456,
                        "quantity": 2,
                        "userId": 123,
                    ],
                ]
            )

            try? await Task.sleep(nanoseconds: 500_000_000)

            // 2. Response (중첩된 dictionary는 기존 API 사용)
            TraceKit.info(
                "API 응답 수신",
                category: "Network",
                metadata: [
                    "statusCode": 201,
                    "duration": 0.512,
                    "responseBody": [
                        "orderId": "ORD-2025-001234",
                        "status": "created",
                        "totalAmount": 59800,
                        "estimatedDelivery": "2025-12-18",
                    ],
                ]
            )

            try? await Task.sleep(nanoseconds: 200_000_000)

            // 3. Completion - 새 API 사용 가능 ✅
            TraceKit.verbose(
                "주문 처리 완료",
                category: "Network",
                ("orderId", "ORD-2025-001234"),
                ("processingTime", 0.712)
            )
        }
    }

    nonisolated private func sampleMessage(for level: TraceLevel) -> String {
        switch level {
        case .verbose:
            "변수 값 확인: count=42, offset=128"
        case .debug:
            "API 요청 준비 중: GET /api/users"
        case .info:
            "사용자가 설정 화면에 진입했습니다"
        case .warning:
            "토큰 만료 10분 전입니다"
        case .error:
            "네트워크 요청 실패: timeout"
        case .fatal:
            "데이터베이스 연결 끊김"
        }
    }
}
