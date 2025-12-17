// DefaultUserContextProvider.swift
// Logger
//
// Created by jimmy on 2025-12-15.

import Foundation
import UIKit

/// 기본 사용자 컨텍스트 제공자
/// - Note: 앱/디바이스 정보를 자동으로 수집
public actor DefaultUserContextProvider: UserContextProvider {
    /// 현재 컨텍스트
    private var context: UserContext

    public init(environment: Environment = .debug) async {
        context = await Self.createInitialContext(environment: environment)
    }

    /// 현재 컨텍스트 반환
    public func currentContext() async -> UserContext {
        context
    }

    /// 사용자 ID 설정
    public func setUserId(_ userId: String?) {
        context.userId = userId
    }

    /// 세션 ID 설정
    public func setSessionId(_ sessionId: String?) {
        context.sessionId = sessionId
    }

    /// 커스텀 속성 설정
    public func setAttribute(key: String, value: AnyCodable) {
        context.customAttributes[key] = value
    }

    /// 커스텀 속성 제거
    public func removeAttribute(key: String) {
        context.customAttributes.removeValue(forKey: key)
    }

    /// 새 세션 시작 (세션 ID 자동 생성)
    public func startNewSession() -> String {
        let sessionId = UUID().uuidString
        context.sessionId = sessionId
        return sessionId
    }

    /// 컨텍스트 초기화
    public func reset() {
        context.userId = nil
        context.sessionId = nil
        context.customAttributes.removeAll()
    }

    // MARK: - Private

    @MainActor
    private static func createInitialContext(environment: Environment) -> UserContext {
        let bundle = Bundle.main
        let device = UIDevice.current

        return UserContext(
            userId: nil,
            sessionId: nil,
            deviceId: getDeviceId(),
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            osVersion: device.systemVersion,
            deviceModel: getDeviceModel(),
            environment: environment,
            customAttributes: [:]
        )
    }

    @MainActor
    private static func getDeviceId() -> String {
        // 키체인이나 UserDefaults에서 저장된 ID 가져오기
        // 여기서는 간단히 identifierForVendor 사용
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
