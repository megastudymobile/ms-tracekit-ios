// SettingsViewModel.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-15.

import Foundation
import TraceKit

@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Settings

    @Published var minLevel: TraceLevel = .verbose
    @Published var isSanitizingEnabled: Bool = true
    @Published var sampleRate: Double = 1.0
    @Published var bufferSize: Int = 100
    @Published var flushInterval: Double = 5.0

    @Published var showAppliedFeedback: Bool = false
    
    // MARK: - Firebase Remote Config
    
    @Published var remoteConfigStatus: String = "대기 중"
    @Published var isRefreshingConfig: Bool = false
    @Published var remoteMinLevel: String = "-"
    @Published var remoteSamplingRate: String = "-"
    @Published var remoteConfigLastFetch: String = "-"

    // MARK: - Log Files

    @Published var logFiles: [LogFileInfo] = []
    @Published var totalLogSize: String = "0 KB"
    @Published var isLoadingFiles: Bool = false
    @Published var selectedFileContent: String?
    @Published var showingFileContent: Bool = false
    @Published var showingShareSheet: Bool = false
    @Published var fileToShare: URL?

    var minLevelIndex: Int {
        get { minLevel.rawValue }
        set { minLevel = TraceLevel(rawValue: newValue) ?? .verbose }
    }

    // MARK: - Init

    init() {
        loadLogFiles()
        loadRemoteConfigStatus()
    }

    // MARK: - Settings Actions

    func applySettings() {
        let configuration = TraceKitConfiguration(
            minLevel: minLevel,
            isSanitizingEnabled: isSanitizingEnabled,
            sampleRate: sampleRate,
            bufferSize: bufferSize,
            flushInterval: flushInterval
        )

        // Capture values before async context for concurrency safety
        let levelName = minLevel.name
        let rate = sampleRate
        
        Task {
            await TraceKit.async.configure(configuration)
            await TraceKit.async.info(
                "설정이 변경되었습니다: minLevel=\(levelName), sampleRate=\(rate)",
                category: "Settings"
            )
        }

        showAppliedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showAppliedFeedback = false
        }
    }

    func resetToDefaults() {
        minLevel = .verbose
        isSanitizingEnabled = true
        sampleRate = 1.0
        bufferSize = 100
        flushInterval = 5.0

        applySettings()
    }
    
    // MARK: - Firebase Remote Config Actions
    
    func loadRemoteConfigStatus() {
        Task {
            let manager = TraceKitSetup.remoteConfigManager
            
            remoteMinLevel = await manager.minimumTraceLevel.name
            remoteSamplingRate = String(format: "%.2f", await manager.samplingRate)
            remoteConfigStatus = "로드됨"
            remoteConfigLastFetch = formatDate(Date())
        }
    }
    
    func refreshRemoteConfig() {
        isRefreshingConfig = true
        remoteConfigStatus = "가져오는 중..."
        
        Task {
            let manager = TraceKitSetup.remoteConfigManager
            let success = await manager.fetchAndActivate()
            
            if success {
                await manager.applyToTraceKit()
                remoteConfigStatus = "적용 완료"
                
                remoteMinLevel = await manager.minimumTraceLevel.name
                remoteSamplingRate = String(format: "%.2f", await manager.samplingRate)
                remoteConfigLastFetch = formatDate(Date())
                
                await TraceKit.async.info(
                    "Remote Config 갱신 완료",
                    category: "Settings"
                )
            } else {
                remoteConfigStatus = "가져오기 실패"
                
                await TraceKit.async.warning(
                    "Remote Config 갱신 실패",
                    category: "Settings"
                )
            }
            
            isRefreshingConfig = false
        }
    }
    
    // MARK: - Log File Actions

    func loadLogFiles() {
        isLoadingFiles = true

        let fileManager = FileManager.default
        let logDirectory = TraceKitSetup.logDirectory

        guard fileManager.fileExists(atPath: logDirectory.path) else {
            logFiles = []
            totalLogSize = "0 KB"
            isLoadingFiles = false
            return
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            var files: [LogFileInfo] = []
            var totalSize: Int64 = 0

            for fileURL in contents where fileURL.pathExtension == "log" {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let size = attributes[FileAttributeKey.size] as? Int64 ?? 0
                let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date ?? Date()

                files.append(LogFileInfo(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    size: size,
                    modificationDate: modificationDate
                ))

                totalSize += size
            }

            logFiles = files.sorted { $0.modificationDate > $1.modificationDate }
            totalLogSize = formatFileSize(totalSize)

        } catch {
            logFiles = []
            totalLogSize = "0 KB"
        }

        isLoadingFiles = false
    }

    func viewFileContent(_ file: LogFileInfo) {
        do {
            let content = try String(contentsOf: file.url, encoding: .utf8)
            selectedFileContent = content
            showingFileContent = true
        } catch {
            selectedFileContent = "파일을 읽을 수 없습니다: \(error.localizedDescription)"
            showingFileContent = true
        }
    }

    func shareFile(_ file: LogFileInfo) {
        fileToShare = file.url
        showingShareSheet = true
    }

    func shareAllLogs() {
        let logDirectory = TraceKitSetup.logDirectory
        fileToShare = logDirectory
        showingShareSheet = true
    }

    func deleteFile(_ file: LogFileInfo) {
        do {
            try FileManager.default.removeItem(at: file.url)
            loadLogFiles()

            TraceKit.info("로그 파일 삭제됨: \(file.name)", category: "Settings")
        } catch {
            TraceKit.error("로그 파일 삭제 실패: \(error.localizedDescription)", category: "Settings")
        }
    }

    func deleteAllLogs() {
        let fileManager = FileManager.default
        let logDirectory = TraceKitSetup.logDirectory

        do {
            let contents = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
            loadLogFiles()

            TraceKit.info("모든 로그 파일이 삭제되었습니다", category: "Settings")
        } catch {
            TraceKit.error("로그 파일 삭제 실패: \(error.localizedDescription)", category: "Settings")
        }
    }

    // MARK: - Helpers

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Log File Info

struct LogFileInfo: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let modificationDate: Date

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
}
