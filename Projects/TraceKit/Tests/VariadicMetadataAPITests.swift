// VariadicMetadataAPITests.swift
// TraceKit
//
// Created by jimmy on 2026-01-28.

import XCTest
@testable import TraceKit

/// Variadic Parameters를 사용한 개선된 metadata API 테스트
///
/// 이 테스트는 새로운 Variadic Parameters API의 기본 동작을 검증합니다.
final class VariadicMetadataAPITests: XCTestCase {
    
    // MARK: - Static API Tests (Fire-and-Forget)
    
    /// 정적 API 컴파일 테스트
    func testStaticVariadicAPI_Compiles() {
        // When/Then - 컴파일 성공 여부 확인
        TraceKit.verbose("Verbose test", ("key", "value"))
        TraceKit.debug("Debug test", ("key", 123))
        TraceKit.info("Info test", ("key", true))
        TraceKit.warning("Warning test", ("key", 3.14))
        TraceKit.error("Error test", ("key1", "value1"), ("key2", "value2"))
        TraceKit.fatal("Fatal test", ("key1", 100), ("key2", "text"))
    }
    
    /// 빈 metadata 테스트
    func testStaticAPI_WithoutMetadata() {
        // When/Then - metadata 없이 호출 가능
        TraceKit.info("Simple message")
        TraceKit.error("Error message")
    }
    
    /// 다양한 타입 지원 테스트
    func testStaticAPI_SupportsVariousTypes() {
        // Given
        let intValue = 42
        let doubleValue = 3.14
        let boolValue = true
        let stringValue = "test"
        
        // When/Then - 다양한 타입이 컴파일되고 실행됨
        TraceKit.info(
            "Type test",
            category: "Test",
            ("int", intValue),
            ("double", doubleValue),
            ("bool", boolValue),
            ("string", stringValue)
        )
    }
    
    /// 실무 시나리오: 네트워크 요청
    func testRealWorldScenario_NetworkRequest() {
        // Given
        let endpoint = "/api/v1/users"
        let method = "GET"
        let statusCode = 200
        let responseTime = 350.5
        
        // When/Then - 실제 사용 패턴이 정상 동작
        TraceKit.info(
            "API 호출 성공",
            category: "Network",
            ("endpoint", endpoint),
            ("method", method),
            ("statusCode", statusCode),
            ("responseTime", responseTime)
        )
    }
    
    /// 실무 시나리오: 결제 실패
    func testRealWorldScenario_PaymentFailure() {
        // Given
        let orderId = "ORD-2026-12345"
        let amount = 59800
        let errorCode = "CARD_LIMIT_EXCEEDED"
        let retryable = true
        
        // When/Then - 에러 로깅 패턴이 정상 동작
        TraceKit.error(
            "결제 실패",
            category: "Payment",
            ("orderId", orderId),
            ("amount", amount),
            ("errorCode", errorCode),
            ("retryable", retryable)
        )
    }
    
    /// 기존 API와의 호환성 테스트
    func testBackwardCompatibility_OriginalAPIStillWorks() {
        // When/Then - 기존 API도 여전히 동작
        TraceKit.info(
            "Original API",
            category: "Test",
            metadata: [
                "key": AnyCodable("value"),
                "number": AnyCodable(123)
            ]
        )
    }
    
    /// 혼용 테스트: 기존 API와 새 API를 함께 사용
    func testMixedUsage_BothAPIsCanBeUsed() {
        // When/Then - 두 API를 자유롭게 혼용 가능
        TraceKit.info("Using original API", metadata: ["key": AnyCodable(1)])
        TraceKit.info("Using variadic API", ("key", 2))
        TraceKit.info("Using original API again", metadata: ["key": AnyCodable(3)])
        TraceKit.info("Using variadic API again", ("key", 4))
    }
    
    /// 복잡한 metadata 테스트
    func testComplexMetadata_WithManyFields() {
        // When/Then - 많은 필드도 처리 가능
        TraceKit.error(
            "복잡한 에러",
            category: "System",
            ("field1", "value1"),
            ("field2", 123),
            ("field3", true),
            ("field4", 3.14),
            ("field5", "value5"),
            ("field6", 456),
            ("field7", false),
            ("field8", 2.71)
        )
    }
    
    /// 카테고리 테스트
    func testVariousCategories() {
        // When/Then - 다양한 카테고리에서 동작
        TraceKit.info("Network log", category: "Network", ("status", 200))
        TraceKit.info("Auth log", category: "Auth", ("userId", "user123"))
        TraceKit.info("Payment log", category: "Payment", ("amount", 59800))
        TraceKit.info("Database log", category: "Database", ("query", "SELECT *"))
    }
    
    /// 메타데이터 변환 로직 테스트
    func testConvertToMetadata_HandlesEmptyArray() {
        // Given
        let emptyMetadata: [(String, Any)] = []
        
        // When
        let result = TraceKit.convertToMetadata(emptyMetadata)
        
        // Then
        XCTAssertNil(result)
    }
    
    /// 메타데이터 변환 로직 테스트
    func testConvertToMetadata_ConvertsSingleValue() {
        // Given
        let metadata: [(String, Any)] = [("key", "value")]
        
        // When
        let result = TraceKit.convertToMetadata(metadata)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?["key"]?.value as? String, "value")
    }
    
    /// 메타데이터 변환 로직 테스트
    func testConvertToMetadata_ConvertsMultipleValues() {
        // Given
        let metadata: [(String, Any)] = [
            ("string", "value"),
            ("int", 123),
            ("bool", true),
            ("double", 3.14)
        ]
        
        // When
        let result = TraceKit.convertToMetadata(metadata)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 4)
        XCTAssertEqual(result?["string"]?.value as? String, "value")
        XCTAssertEqual(result?["int"]?.value as? Int, 123)
        XCTAssertEqual(result?["bool"]?.value as? Bool, true)
        XCTAssertEqual(result?["double"]?.value as? Double, 3.14)
    }
}

// MARK: - Test Helper Extension

extension TraceKit {
    /// 테스트용 helper - convertToMetadata를 공개
    nonisolated static func convertToMetadata(_ metadata: [(String, Any)]) -> [String: AnyCodable]? {
        guard !metadata.isEmpty else { return nil }
        return Dictionary(uniqueKeysWithValues: metadata.map { ($0, AnyCodable($1)) })
    }
}
