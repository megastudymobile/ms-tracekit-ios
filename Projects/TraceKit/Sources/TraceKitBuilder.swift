// TraceKitBuilder.swift
// TraceKit
//
// Created by jimmy on 2025-12-15.

import Foundation

/// 로거 빌더
/// - Note: 빌더 패턴으로 TraceKit 구성
public final class TraceKitBuilder: @unchecked Sendable {
    // MARK: - Properties

    private var destinations: [any TraceDestination] = []
    private var configuration: TraceKitConfiguration = .default
    private var bufferPolicy: TraceBufferPolicy?
    private var samplingPolicy: SamplingPolicy?
    private var sanitizer: TraceSanitizer?
    private var contextProvider: (any UserContextProvider)?
    private var useDefaultContextProvider: Environment?
    private var crashPreserveCount: Int?
    private var applyLaunchArgs: Bool = false

    // MARK: - Init

    public init() {}

    // MARK: - Builder Methods

    /// Destination 추가
    @discardableResult
    public func addDestination(_ destination: any TraceDestination) -> Self {
        destinations.append(destination)
        return self
    }

    /// 콘솔 Destination 추가
    @discardableResult
    public func addConsole(
        minLevel: TraceLevel = .verbose,
        formatter: TraceFormatter = PrettyTraceFormatter.standard
    ) -> Self {
        let console = ConsoleTraceDestination(
            minLevel: minLevel,
            formatter: formatter
        )
        return addDestination(console)
    }

    /// OSLog Destination 추가
    @available(iOS 14.0, *)
    @discardableResult
    public func addOSLog(
        subsystem: String = Bundle.main.bundleIdentifier ?? "com.tracekit",
        minLevel: TraceLevel = .verbose,
        formatter: TraceFormatter? = nil
    ) -> Self {
        let oslog = OSTraceDestination(
            subsystem: subsystem,
            minLevel: minLevel,
            formatter: formatter
        )
        return addDestination(oslog)
    }

    /// 파일 Destination 추가
    @discardableResult
    public func addFile(
        minLevel: TraceLevel = .verbose,
        retentionPolicy: TraceFileRetentionPolicy = .default
    ) -> Self {
        let fileManager = TraceFileManager(baseDirectory: nil, retentionPolicy: retentionPolicy)
        let file = FileTraceDestination(
            minLevel: minLevel,
            fileManager: fileManager
        )
        return addDestination(file)
    }

    /// 설정 적용
    @discardableResult
    public func with(configuration: TraceKitConfiguration) -> Self {
        self.configuration = configuration
        return self
    }

    /// 버퍼 정책 설정
    @discardableResult
    public func withBuffer(policy: TraceBufferPolicy = .default) -> Self {
        bufferPolicy = policy
        return self
    }

    /// 샘플링 정책 설정
    @discardableResult
    public func withSampling(policy: SamplingPolicy) -> Self {
        samplingPolicy = policy
        return self
    }

    /// 정제기 설정
    @discardableResult
    public func withSanitizer(_ sanitizer: TraceSanitizer) -> Self {
        self.sanitizer = sanitizer
        return self
    }

    /// 기본 정제기 사용
    @discardableResult
    public func withDefaultSanitizer() -> Self {
        sanitizer = DefaultTraceSanitizer()
        return self
    }

    /// 컨텍스트 제공자 설정
    @discardableResult
    public func withContextProvider(_ provider: any UserContextProvider) -> Self {
        contextProvider = provider
        return self
    }

    /// 기본 컨텍스트 제공자 사용
    @discardableResult
    public func withDefaultContextProvider(environment: Environment = .debug) -> Self {
        useDefaultContextProvider = environment
        return self
    }

    /// 크래시 로그 보존 활성화
    @discardableResult
    public func withCrashPreservation(count: Int = 50) -> Self {
        crashPreserveCount = count
        return self
    }

    /// Launch Argument 오버라이드 적용
    @discardableResult
    public func applyLaunchArguments() -> Self {
        applyLaunchArgs = true
        return self
    }

    // MARK: - Build

    /// TraceKit 빌드
    @TraceKitActor
    public func build() async -> TraceKit {
        // Launch Argument 적용
        var finalConfig = configuration
        if applyLaunchArgs, let launchConfig = LaunchArgumentParser.parse() {
            finalConfig = finalConfig.merged(with: launchConfig)
        }

        let logger = TraceKit(configuration: finalConfig)

        // Destinations 추가
        for destination in destinations {
            logger.addDestination(destination)
        }

        // 버퍼 설정
        if let bufferPolicy = bufferPolicy {
            let buffer = TraceBuffer(policy: bufferPolicy)
            logger.setBuffer(buffer)
        }

        // 샘플러 설정
        if let samplingPolicy = samplingPolicy {
            let sampler = TraceSampler(policy: samplingPolicy)
            logger.setSampler(sampler)
        }

        // 정제기 설정
        if let sanitizer = sanitizer {
            logger.setSanitizer(sanitizer)
        }

        // 컨텍스트 제공자 설정
        if let contextProvider = contextProvider {
            logger.setContextProvider(contextProvider)
        } else if let environment = useDefaultContextProvider {
            let defaultProvider = await DefaultUserContextProvider(environment: environment)
            logger.setContextProvider(defaultProvider)
        }

        // 크래시 보존기 설정
        if let crashPreserveCount = crashPreserveCount {
            let crashPreserver = CrashTracePreserver(preserveCount: crashPreserveCount)
            logger.setCrashPreserver(crashPreserver)
        }

        return logger
    }

    /// 공유 인스턴스로 빌드
    @TraceKitActor
    @discardableResult
    public func buildAsShared() async -> TraceKit {
        let logger = await build()
        TraceKit.setShared(logger)
        return logger
    }
}

// MARK: - Convenience

public extension TraceKitBuilder {
    /// 디버그용 기본 설정
    static func debug() -> TraceKitBuilder {
        TraceKitBuilder()
            .addConsole(formatter: PrettyTraceFormatter.verbose)
            .with(configuration: .debug)
            .withDefaultSanitizer()
            .applyLaunchArguments()
    }

    /// 프로덕션용 기본 설정
    @available(iOS 14.0, *)
    static func production() -> TraceKitBuilder {
        TraceKitBuilder()
            .addConsole(minLevel: .warning)
            .addOSLog(minLevel: .info)
            .addFile(minLevel: .info)
            .with(configuration: .production)
            .withBuffer(policy: .default)
            .withSampling(policy: .production)
            .withDefaultSanitizer()
            .withCrashPreservation()
            .applyLaunchArguments()
    }
}
