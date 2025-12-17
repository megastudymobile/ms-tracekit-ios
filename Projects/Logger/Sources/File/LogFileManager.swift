// LogFileManager.swift
// Logger
//
// Created by jimmy on 2025-12-15.

import Foundation

/// 로그 파일 관리자
/// - Note: 파일 생성, 삭제, 보관 기간 관리
public actor LogFileManager {
    /// 로그 파일 기본 디렉토리
    private let baseDirectory: URL

    /// 보관 정책
    private let retentionPolicy: LogFileRetentionPolicy

    /// 현재 로그 파일 URL
    private var currentLogFileURL: URL?

    /// 현재 파일 핸들
    private var fileHandle: FileHandle?

    /// 현재 파일 크기
    private var currentFileSize: Int = 0

    /// 날짜 포맷터
    private let dateFormatter: DateFormatter

    /// 자동 정리 태스크
    private var cleanupTask: Task<Void, Never>?

    /// 파일 매니저
    private let fm = FileManager.default

    public init(
        baseDirectory: URL? = nil,
        retentionPolicy: LogFileRetentionPolicy = .default
    ) {
        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.baseDirectory = cachesDir.appendingPathComponent("Logs", isDirectory: true)
        }

        self.retentionPolicy = retentionPolicy

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = retentionPolicy.dateFormat

        // 디렉토리 생성
        try? fm.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
    }

    /// 로그 내용 추가
    public func append(_ content: String) throws {
        let fileURL = try getOrCreateCurrentLogFile()

        guard let data = content.data(using: .utf8) else {
            throw LogFileError.encodingFailed
        }

        if fileHandle == nil {
            fileHandle = try FileHandle(forWritingTo: fileURL)
            fileHandle?.seekToEndOfFile()
        }

        fileHandle?.write(data)
        currentFileSize += data.count

        // 파일 크기 초과 시 새 파일 생성
        if currentFileSize >= retentionPolicy.maxFileSize {
            closeCurrentFile()
        }
    }

    /// 모든 로그 파일 목록
    public func allLogFiles() throws -> [URL] {
        let files = try fm.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        return files
            .filter { $0.pathExtension == retentionPolicy.fileExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 보관 기간 지난 파일 정리
    public func cleanup() throws {
        let files = try allLogFiles()
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -retentionPolicy.retentionDays,
            to: Date()
        )!

        var totalSize = 0
        var filesToDelete: [URL] = []

        for file in files {
            let attributes = try fm.attributesOfItem(atPath: file.path)
            let creationDate = attributes[.creationDate] as? Date ?? Date.distantPast
            let fileSize = attributes[.size] as? Int ?? 0

            // 보관 기간 초과
            if creationDate < cutoffDate {
                filesToDelete.append(file)
                continue
            }

            totalSize += fileSize
        }

        // 전체 크기 초과 시 오래된 파일부터 삭제
        if let maxTotalSize = retentionPolicy.maxTotalSize {
            let sortedFiles = files.sorted { file1, file2 in
                let date1 = (try? fm.attributesOfItem(atPath: file1.path)[.creationDate] as? Date) ?? Date()
                let date2 = (try? fm.attributesOfItem(atPath: file2.path)[.creationDate] as? Date) ?? Date()
                return date1 < date2
            }

            var currentTotal = totalSize
            for file in sortedFiles {
                if currentTotal <= maxTotalSize { break }
                if !filesToDelete.contains(file) {
                    let fileSize = (try? fm.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
                    filesToDelete.append(file)
                    currentTotal -= fileSize
                }
            }
        }

        // 파일 삭제
        for file in filesToDelete {
            try? fm.removeItem(at: file)
        }
    }

    /// 로그 파일 내보내기 (특정 기간)
    public func exportLogs(from startDate: Date, to endDate: Date) throws -> URL {
        let files = try allLogFiles()
        let exportDir = fm.temporaryDirectory.appendingPathComponent("LogExport-\(UUID().uuidString)")
        try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)

        for file in files {
            let attributes = try fm.attributesOfItem(atPath: file.path)
            guard let creationDate = attributes[.creationDate] as? Date,
                  creationDate >= startDate && creationDate <= endDate
            else {
                continue
            }

            let destination = exportDir.appendingPathComponent(file.lastPathComponent)
            try fm.copyItem(at: file, to: destination)
        }

        return exportDir
    }

    /// 자동 정리 시작
    public func startAutoCleanup() {
        cleanupTask?.cancel()
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                try? await Task.sleep(nanoseconds: UInt64(self.retentionPolicy.cleanupInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                try? await self.cleanup()
            }
        }
    }

    /// 자동 정리 중지
    public func stopAutoCleanup() {
        cleanupTask?.cancel()
        cleanupTask = nil
    }

    /// 현재 파일 닫기
    public func closeCurrentFile() {
        try? fileHandle?.synchronize()
        try? fileHandle?.close()
        fileHandle = nil
        currentLogFileURL = nil
        currentFileSize = 0
    }

    // MARK: - Private

    private func getOrCreateCurrentLogFile() throws -> URL {
        let today = dateFormatter.string(from: Date())
        let fileName = "log-\(today).\(retentionPolicy.fileExtension)"
        let fileURL = baseDirectory.appendingPathComponent(fileName)

        // 날짜가 바뀌었거나 파일이 없으면 새로 생성
        if currentLogFileURL?.lastPathComponent != fileName {
            closeCurrentFile()

            if !fm.fileExists(atPath: fileURL.path) {
                fm.createFile(atPath: fileURL.path, contents: nil)
            }

            currentLogFileURL = fileURL
            currentFileSize = (try? fm.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        }

        return fileURL
    }

    deinit {
        cleanupTask?.cancel()
    }
}

// MARK: - Errors

public enum LogFileError: Error {
    case encodingFailed
    case fileNotFound
    case writeFailed
}
