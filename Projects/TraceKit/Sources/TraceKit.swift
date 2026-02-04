// TraceKit.swift
// TraceKit
//
// Created by jimmy on 2025-12-15.

import Foundation

/// 메인 로거 클래스
/// - Note: 로그 수집, 필터링, 분배를 담당하는 파사드
@TraceKitActor
public final class TraceKit {
    // MARK: - Singleton

    /// 공유 인스턴스 (내부 사용, 초기화 후 불변)
    /// - Note: TraceKitBuilder.buildAsShared()를 통해 설정됨
    private static var _shared: TraceKit?

    /// 공유 인스턴스 접근
    private static var shared: TraceKit {
        guard let instance = _shared else {
            // 기본 인스턴스 생성 (설정되지 않은 경우)
            let defaultTraceKit = TraceKit()
            _shared = defaultTraceKit
            return defaultTraceKit
        }
        return instance
    }

    /// Async 로거 인스턴스
    /// - Note: 순서 보장이 필요한 경우 사용. `await TraceKit.async.info(...)`
    public static var async: TraceKit { shared }

    /// 공유 인스턴스 설정 (내부 전용)
    static func setShared(_ logger: TraceKit) {
        _shared = logger
    }

    // MARK: - Properties

    /// 로그 목적지 목록
    private var destinations: [any TraceDestination] = []

    /// 설정
    private var configuration: TraceKitConfiguration

    /// 로그 버퍼
    private var buffer: TraceBuffer?

    /// 샘플러
    private var sampler: TraceSampler?

    /// 정제기
    private var sanitizer: TraceSanitizer?

    /// 사용자 컨텍스트 제공자
    private var contextProvider: (any UserContextProvider)?

    /// 크래시 로그 보존기
    private var crashPreserver: CrashTracePreserver?

    /// 성능 추적기
    public private(set) var tracer: PerformanceTracer

    // MARK: - Init

    public init(configuration: TraceKitConfiguration = .default) {
        self.configuration = configuration
        tracer = PerformanceTracer()
    }

    // MARK: - Configuration

    /// 설정 업데이트
    ///
    /// 런타임에 TraceKit의 동작을 동적으로 변경합니다.
    /// - Remote Config를 통한 원격 제어
    /// - A/B 테스트 및 긴급 디버깅 모드 활성화
    /// - 프로덕션 환경에서 로그 레벨 조정
    ///
    /// - Parameter newConfiguration: 적용할 새로운 설정
    public func configure(_ newConfiguration: TraceKitConfiguration) {
        let oldConfiguration = configuration
        configuration = newConfiguration

        // 샘플러 업데이트 (새 샘플링 비율로 재생성)
        if sampler != nil {
            let newPolicy = SamplingPolicy(defaultRate: newConfiguration.sampleRate)
            sampler = TraceSampler(policy: newPolicy)
        }

        // 버퍼 정책 업데이트
        if let buffer = buffer {
            Task {
                await buffer.stopAutoFlush()
                await buffer.startAutoFlush { [weak self] messages in
                    await self?.dispatchToDestinations(messages)
                }
            }
        }

        // 설정 변경 로깅
        Task { @TraceKitActor in
            await self.info(
                "TraceKit 설정 업데이트 완료",
                category: "Configuration",
                metadata: [
                    "old_min_level": AnyCodable(oldConfiguration.minLevel.name),
                    "new_min_level": AnyCodable(newConfiguration.minLevel.name),
                    "old_sample_rate": AnyCodable(oldConfiguration.sampleRate),
                    "new_sample_rate": AnyCodable(newConfiguration.sampleRate),
                    "old_sanitizer": AnyCodable(oldConfiguration.isSanitizingEnabled),
                    "new_sanitizer": AnyCodable(newConfiguration.isSanitizingEnabled),
                ]
            )
        }
    }

    /// Destination 추가
    public func addDestination(_ destination: any TraceDestination) {
        destinations.append(destination)
    }

    /// Destination 제거
    public func removeDestination(identifier _: String) {
        destinations.removeAll { _ in
            // Actor isolated property 접근을 위해 Task 사용
            false // 실제로는 identifier 비교 필요
        }
    }

    /// 버퍼 설정
    public func setBuffer(_ buffer: TraceBuffer) {
        self.buffer = buffer

        Task {
            await buffer.startAutoFlush { [weak self] messages in
                await self?.dispatchToDestinations(messages)
            }
        }
    }

    /// 샘플러 설정
    public func setSampler(_ sampler: TraceSampler) {
        self.sampler = sampler
    }

    /// 정제기 설정
    public func setSanitizer(_ sanitizer: TraceSanitizer) {
        self.sanitizer = sanitizer
    }

    /// 컨텍스트 제공자 설정
    public func setContextProvider(_ provider: any UserContextProvider) {
        contextProvider = provider
    }

    /// 크래시 보존기 설정
    public func setCrashPreserver(_ preserver: CrashTracePreserver) {
        crashPreserver = preserver
    }

    /// PerformanceTracer를 TraceKit 로그 파이프라인에 연결
    ///
    /// PerformanceTracer의 span 완료 로그가 TraceKit의 모든 Destination으로 전송되도록 합니다.
    /// - Note: `TraceKitBuilder.buildAsShared()` 에서 자동으로 호출됩니다.
    public func connectTracerToLogging() async {
        await tracer.setLogHandler { [weak self] level, message, category, metadata in
            guard let self = self else { return }

            // PerformanceTracer의 로그를 TraceKit 파이프라인으로 전달
            await self.log(
                level: level,
                message,
                category: category,
                metadata: metadata,
                file: "PerformanceTracer.swift",
                function: "endSpan(id:metadata:)",
                line: 50
            )
        }
    }

    // MARK: - Logging Methods

    /// 로그 출력
    public func log(
        level: TraceLevel,
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        // 레벨 필터링
        guard level >= configuration.minLevel else { return }

        // 카테고리 필터링
        if let enabledCategories = configuration.enabledCategories,
           !enabledCategories.contains(category)
        {
            return
        }

        // 메시지 생성 (lazy evaluation)
        var logMessage = TraceMessage(
            level: level,
            message: message(),
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )

        // 샘플링
        if let sampler = sampler, !sampler.shouldLog(logMessage) {
            return
        }

        // 사용자 컨텍스트 추가
        if let contextProvider = contextProvider {
            let context = await contextProvider.currentContext()
            logMessage = logMessage.withUserContext(context)
        }

        // 정제 (민감정보 마스킹)
        if configuration.isSanitizingEnabled, let sanitizer = sanitizer {
            logMessage = sanitizer.sanitize(logMessage)
        }

        // 크래시 보존
        if let crashPreserver = crashPreserver {
            await crashPreserver.record(logMessage)
        }

        // 버퍼링 또는 즉시 출력
        if let buffer = buffer {
            await buffer.append(logMessage)
        } else {
            await dispatchToDestinations([logMessage])
        }
    }

    // MARK: - Convenience Methods

    public func verbose(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(
            level: .verbose,
            message(),
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func debug(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(
            level: .debug,
            message(),
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func info(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(
            level: .info,
            message(),
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func warning(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(
            level: .warning,
            message(),
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func error(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(
            level: .error,
            message(),
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func fatal(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(
            level: .fatal,
            message(),
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    // MARK: - Performance Tracing

    /// 성능 측정 시작
    public func startSpan(name: String, parentId: UUID? = nil) async -> UUID {
        await tracer.startSpan(name: name, parentId: parentId)
    }

    /// 성능 측정 종료
    public func endSpan(id: UUID, metadata: [String: AnyCodable] = [:]) async {
        await tracer.endSpan(id: id, metadata: metadata)
    }

    /// 측정 블록 실행
    public func measure<T: Sendable>(
        name: String,
        parentId: UUID? = nil,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await tracer.measure(name: name, parentId: parentId, operation: operation)
    }

    // MARK: - Crash Recovery

    /// 크래시 로그 복구
    public func recoverCrashLogs() async -> [TraceMessage]? {
        guard let crashPreserver = crashPreserver else { return nil }
        return try? await crashPreserver.recover()
    }

    /// 크래시 로그 정리
    public func clearCrashLogs() async {
        try? await crashPreserver?.clear()
    }

    // MARK: - Flush

    /// 버퍼 플러시
    public func flush() async {
        guard let buffer = buffer else { return }
        let messages = await buffer.flush()
        await dispatchToDestinations(messages)
    }

    // MARK: - Private

    private func dispatchToDestinations(_ messages: [TraceMessage]) async {
        guard !messages.isEmpty else { return }

        for destination in destinations {
            let identifier = await destination.identifier

            // 비활성화된 destination 스킵
            if configuration.disabledDestinations.contains(identifier) {
                continue
            }

            await destination.flush(messages)
        }
    }
}

// MARK: - Static Fire-and-Forget API

public extension TraceKit {
    /// 정적 로그 출력 (Fire-and-Forget)
    /// - Note: await 없이 호출 가능. 내부적으로 Task를 생성하여 비동기 처리
    nonisolated static func log(
        level: TraceLevel,
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let capturedMessage = message()
        Task { @TraceKitActor in
            await shared.log(
                level: level,
                capturedMessage,
                category: category,
                metadata: metadata,
                file: file,
                function: function,
                line: line
            )
        }
    }

    /// 정적 verbose 로그 (Fire-and-Forget)
    nonisolated static func verbose(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .verbose, message(), category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// 정적 debug 로그 (Fire-and-Forget)
    nonisolated static func debug(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message(), category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// 정적 info 로그 (Fire-and-Forget)
    nonisolated static func info(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message(), category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// 정적 warning 로그 (Fire-and-Forget)
    nonisolated static func warning(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message(), category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// 정적 error 로그 (Fire-and-Forget)
    nonisolated static func error(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message(), category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// 정적 fatal 로그 (Fire-and-Forget)
    nonisolated static func fatal(
        _ message: @autoclosure @Sendable () -> String,
        category: String = "Default",
        metadata: [String: AnyCodable]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .fatal, message(), category: category, metadata: metadata, file: file, function: function, line: line)
    }
}
