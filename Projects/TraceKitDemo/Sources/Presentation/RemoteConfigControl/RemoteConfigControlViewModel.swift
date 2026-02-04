// RemoteConfigControlViewModel.swift
// TraceKitDemo
//
// Created by jimmy on 2026-01-22.

import Foundation
import TraceKit

/// Remote Config 설정 스냅샷
struct RemoteConfigSnapshot {
    let minLevel: TraceLevel
    let samplingRate: Double
    let isCrashlyticsEnabled: Bool
    let isAnalyticsEnabled: Bool
    let isPerformanceEnabled: Bool
    let isSanitizerEnabled: Bool
    let lastFetchTime: Date?
    
    var samplingRatePercentage: String {
        String(format: "%.0f%%", samplingRate * 100)
    }
}

/// Remote Config Live Control ViewModel
///
/// Firebase Remote Config를 통한 TraceKit 동적 제어를 시연합니다.
/// Console에서 설정을 변경하고 앱에서 즉시 fetch하여 반영을 확인할 수 있습니다.
@MainActor
final class RemoteConfigControlViewModel: ObservableObject {
    @Published var currentConfig: RemoteConfigSnapshot?
    @Published var isFetching: Bool = false
    @Published var lastFetchStatus: FetchStatus = .idle
    @Published var errorMessage: String?
    @Published var isRealtimeEnabled: Bool = false
    
    // TraceKitSetup의 공유 인스턴스 사용
    private var remoteConfigManager: FirebaseRemoteConfigManager {
        TraceKitSetup.remoteConfigManager
    }
    
    enum FetchStatus {
        case idle
        case fetching
        case success
        case failed
        case realtimeUpdate // 실시간 업데이트로 인한 변경
        
        var displayText: String {
            switch self {
            case .idle: return "대기 중"
            case .fetching: return "가져오는 중..."
            case .success: return "성공"
            case .failed: return "실패"
            case .realtimeUpdate: return "자동 업데이트"
            }
        }
        
        var color: Theme.Colors.Type {
            switch self {
            case .idle: return Theme.Colors.self
            case .fetching: return Theme.Colors.self
            case .success: return Theme.Colors.self
            case .failed: return Theme.Colors.self
            case .realtimeUpdate: return Theme.Colors.self
            }
        }
    }
    
    init() {
        // 초기 설정 로드
        Task {
            await loadCurrentConfig()
            // 실시간 업데이트는 TraceKitSetup에서 이미 시작됨
            isRealtimeEnabled = true
        }
        
        // Remote Config 업데이트 알림 구독
        NotificationCenter.default.addObserver(
            forName: .remoteConfigDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.lastFetchStatus = .realtimeUpdate
                await self.loadCurrentConfig()
                
                // 설정 변경 시간 업데이트
                if var config = self.currentConfig {
                    config = RemoteConfigSnapshot(
                        minLevel: config.minLevel,
                        samplingRate: config.samplingRate,
                        isCrashlyticsEnabled: config.isCrashlyticsEnabled,
                        isAnalyticsEnabled: config.isAnalyticsEnabled,
                        isPerformanceEnabled: config.isPerformanceEnabled,
                        isSanitizerEnabled: config.isSanitizerEnabled,
                        lastFetchTime: Date()
                    )
                    self.currentConfig = config
                }
                
                // 3초 후 상태 초기화
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if self.lastFetchStatus == .realtimeUpdate {
                    self.lastFetchStatus = .idle
                }
            }
        }
    }
    
    /// 현재 Remote Config 설정 로드
    func loadCurrentConfig() async {
        let snapshot = RemoteConfigSnapshot(
            minLevel: await remoteConfigManager.minimumTraceLevel,
            samplingRate: await remoteConfigManager.samplingRate,
            isCrashlyticsEnabled: await remoteConfigManager.isCrashlyticsEnabled,
            isAnalyticsEnabled: await remoteConfigManager.isAnalyticsEnabled,
            isPerformanceEnabled: await remoteConfigManager.isPerformanceEnabled,
            isSanitizerEnabled: await remoteConfigManager.isSanitizerEnabled,
            lastFetchTime: nil
        )
        
        currentConfig = snapshot
    }
    
    /// Remote Config 새로고침 (Fetch & Activate)
    /// 캐시를 무시하고 서버에서 즉시 최신 설정을 가져옵니다.
    func fetchAndActivate() async {
        isFetching = true
        lastFetchStatus = .fetching
        errorMessage = nil
        
        do {
            // 캐시 무시하고 즉시 가져오기
            let success = await remoteConfigManager.fetchAndActivateImmediately()
            
            if success {
                lastFetchStatus = .success
                await loadCurrentConfig()
                
                // 현재 시간을 lastFetchTime으로 설정
                if var config = currentConfig {
                    config = RemoteConfigSnapshot(
                        minLevel: config.minLevel,
                        samplingRate: config.samplingRate,
                        isCrashlyticsEnabled: config.isCrashlyticsEnabled,
                        isAnalyticsEnabled: config.isAnalyticsEnabled,
                        isPerformanceEnabled: config.isPerformanceEnabled,
                        isSanitizerEnabled: config.isSanitizerEnabled,
                        lastFetchTime: Date()
                    )
                    currentConfig = config
                }
                
                // TraceKit에 즉시 적용
                await remoteConfigManager.applyToTraceKit()
            } else {
                lastFetchStatus = .failed
                errorMessage = "설정을 가져오는데 실패했습니다"
            }
        } catch {
            lastFetchStatus = .failed
            errorMessage = error.localizedDescription
        }
        
        isFetching = false
        
        // 3초 후 상태 초기화
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if lastFetchStatus != .fetching {
            lastFetchStatus = .idle
        }
    }
    
    /// 긴급 디버깅 모드 시나리오
    func demonstrateEmergencyDebug() {
        // 실제로는 Firebase Console에서 수동으로 변경해야 함
        TraceKit.info(
            "긴급 디버깅 모드 시나리오",
            category: "RemoteConfig",
            ("scenario", "emergency_debug"),
            ("action", "Firebase Console에서 tracekit_min_level을 'verbose'로 변경하세요")
        )
    }
    
    /// A/B 테스트 시나리오
    func demonstrateABTest() {
        TraceKit.info(
            "A/B 테스트 시나리오",
            category: "RemoteConfig",
            ("scenario", "ab_test"),
            ("action", "Firebase Console에서 조건부 값을 설정하세요")
        )
    }
    
    /// 설정 변경 여부 확인
    func hasConfigChanged(from previous: RemoteConfigSnapshot?) -> Bool {
        guard let previous = previous, let current = currentConfig else {
            return false
        }
        
        return previous.minLevel != current.minLevel ||
               previous.samplingRate != current.samplingRate ||
               previous.isCrashlyticsEnabled != current.isCrashlyticsEnabled ||
               previous.isAnalyticsEnabled != current.isAnalyticsEnabled ||
               previous.isPerformanceEnabled != current.isPerformanceEnabled ||
               previous.isSanitizerEnabled != current.isSanitizerEnabled
    }
    
    /// 마지막 갱신 시간 표시
    var lastFetchTimeDisplay: String {
        guard let fetchTime = currentConfig?.lastFetchTime else {
            return "아직 갱신하지 않음"
        }
        
        let interval = Date().timeIntervalSince(fetchTime)
        
        if interval < 60 {
            return "방금 전"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)분 전"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)시간 전"
        }
    }
}
