// TraceKitSetup.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-15.

import Foundation
import TraceKit
import FirebaseCore
import FirebaseCrashlytics
import FirebaseAnalytics
import FirebaseRemoteConfig

/// TraceKit 초기화 설정
///
/// 데모 앱에서 사용할 TraceKit을 구성합니다.
/// - OSLog 출력 (PrettyTraceFormatter.verbose) - Xcode 콘솔 및 Console.app
/// - File 출력 (JSONTraceFormatter) - 디바이스에 로그 파일 저장
/// - InMemoryTraceDestination (앱 내 로그 뷰어용)
/// - Firebase Crashlytics (크래시 리포트 및 Breadcrumb)
/// - Firebase Analytics (에러 이벤트 추적)
/// - Firebase Remote Config (동적 설정 제어)
/// - 민감정보 마스킹 활성화
/// - CrashTracePreserver (크래시 로그 보존)
///
/// ## 사용 예시
/// ```swift
/// Task {
///     await TraceKitSetup.configure()
/// }
/// ```
///
/// ## 구성된 Destination
/// | Destination | 용도 |
/// |------------|------|
/// | OSLog | Xcode 콘솔, Console.app, Instruments 연동 (PrettyTraceFormatter 적용) |
/// | File | 디바이스에 JSON 형식 로그 파일 저장 (7일 보관) |
/// | InMemory | TraceViewer 화면에서 실시간 로그 확인 |
/// | Crashlytics | Firebase Crashlytics Breadcrumb 및 에러 리포트 |
/// | Analytics | Firebase Analytics 이벤트 전송 (에러 패턴 분석) |
/// | CrashTracePreserver | 크래시 직전 로그 보존 및 복구 |
///
/// ## Firebase 통합
/// - **Crashlytics**: 크래시 발생 시 TraceKit 로그 컨텍스트 첨부
/// - **Analytics**: 에러/크리티컬 로그를 이벤트로 전송하여 패턴 분석
/// - **Remote Config**: 앱 업데이트 없이 로그 레벨, 샘플링 비율 등 동적 제어
///
/// ## 로그 파일 위치
/// `Library/Caches/Logs/log-YYYY-MM-DD.log`
///
/// - Note: 앱 시작 시 `TraceKitDemoApp.init()`에서 호출됩니다.
enum TraceKitSetup {
    /// 공유 CrashTracePreserver 인스턴스
    static let crashPreserver = CrashTracePreserver(preserveCount: 100)
    
    /// Remote Config 관리자
    static let remoteConfigManager = FirebaseRemoteConfigManager()

    /// TraceKit 초기화
    ///
    /// 앱 시작 시 한 번 호출하여 TraceKit을 구성합니다.
    /// 전역 TraceKit 인스턴스가 설정되며, static 메서드를 통해 접근할 수 있습니다.
    ///
    /// - Important: MainActor에서 실행되어야 합니다.
    @MainActor
    static func configure() async {
        // Firebase 초기화
        configureFirebase()
        
        // Remote Config 가져오기
        await remoteConfigManager.fetchAndActivate()
        
        // 이전 크래시 확인
        await checkPreviousCrash()

        let stream = TraceStream.shared
        let inMemoryDestination = InMemoryTraceDestination(stream: stream)
        
        // Firebase Destinations
        let crashlyticsDestination = FirebaseCrashlyticsTraceDestination()
        let analyticsDestination = FirebaseAnalyticsTraceDestination()

        _ = await TraceKitBuilder()
            .addOSLog(
                subsystem: "com.tracekit.TraceKitDemo",
                formatter: PrettyTraceFormatter.verbose
            )
            .addFile(
                minLevel: .debug,
                retentionPolicy: .default
            )
            .addDestination(inMemoryDestination)
            .addDestination(crashlyticsDestination)
            .addDestination(analyticsDestination)
            .with(configuration: .debug)
            .withDefaultSanitizer()
            .buildAsShared()
        
        // Remote Config 설정 적용
        await remoteConfigManager.applyToTraceKit()
        
        // Remote Config 실시간 업데이트 활성화
        await remoteConfigManager.startRealtimeUpdates()
        print("✅ [Remote Config] 실시간 업데이트 활성화")

        // Signal Handler 등록 (전역 mmap 포인터 사용)
        // registerSignalHandlers()
    }
    
    /// Firebase 초기화
    ///
    /// GoogleService-Info.plist를 사용하여 Firebase를 구성합니다.
    /// Crashlytics와 Analytics를 활성화합니다.
    @MainActor
    private static func configureFirebase() {
        FirebaseApp.configure()
        print("✅ [Firebase] 초기화 완료")
        
        // Crashlytics 활성화
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        print("✅ [Firebase Crashlytics] 활성화")
    }

    /// 이전 크래시 확인 및 로그 복구
    @MainActor
    private static func checkPreviousCrash() async {
        do {
            if let logs = try await crashPreserver.recover() {
                print("⚠️ [CrashTracePreserver] 이전 크래시 감지: \(logs.count)개 로그 복구됨")

                // 복구된 로그 출력 (상위 5개만)
                for log in logs.prefix(5) {
                    print("  - [\(log.level.name)] \(log.message)")
                }

                if logs.count > 5 {
                    print("  ... 외 \(logs.count - 5)개")
                }
            }
        } catch {
            print("⚠️ [CrashTracePreserver] 크래시 로그 복구 실패: \(error)")
        }
    }

    /// Signal Handler 등록 (옵션)
    /// - Warning: 프로덕션에서 사용 시 주의 필요
    @MainActor
    static func registerSignalHandlers() {
        // CrashTracePreserver.registerSignalHandlersUnsafe(...)
        // 주의: Actor의 mmap 포인터에 직접 접근할 수 없으므로
        // 실제 구현 시 전역 변수나 다른 방법 필요
    }

    /// 로그 파일 디렉토리 URL
    static var logDirectory: URL {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesDir.appendingPathComponent("Logs", isDirectory: true)
    }
}
