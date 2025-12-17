// CrashLogPreserver.swift
// Logger
//
// Created by jimmy on 2025-12-15.

import Foundation

/// 크래시 로그 보존기
/// - Note: 크래시 직전 로그를 저장하고 다음 실행 시 복구
public actor CrashLogPreserver {
    /// 링 버퍼 (최근 N개 로그 보관)
    private var ringBuffer: RingBuffer<LogMessage>

    /// 보존할 로그 수
    public nonisolated let preserveCount: Int

    /// 저장 파일 URL
    private let storageURL: URL

    /// 파일 매니저
    private let fm = FileManager.default

    /// JSON 인코더/디코더
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - mmap 기반 동기 저장

    /// mmap된 메모리 포인터
    private nonisolated(unsafe) var mmapPtr: UnsafeMutableRawPointer?

    /// mmap 파일 디스크립터
    private nonisolated(unsafe) var mmapFD: Int32 = -1

    /// mmap 크기 (최대 1MB)
    private nonisolated let mmapSize: Int = 1024 * 1024

    /// 동기 저장용 잠금
    private nonisolated(unsafe) var syncLock = os_unfair_lock()

    public init(
        preserveCount: Int = 50,
        storageURL: URL? = nil
    ) {
        self.preserveCount = preserveCount
        ringBuffer = RingBuffer(capacity: preserveCount)

        if let storageURL = storageURL {
            self.storageURL = storageURL
        } else {
            let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.storageURL = cachesDir.appendingPathComponent("crash_logs.json")
        }

        // mmap 초기화 (별도 파일 사용)
        setupMmap()
    }

    /// mmap 메모리 매핑 설정
    private nonisolated func setupMmap() {
        let mmapPath = storageURL.deletingPathExtension()
            .appendingPathExtension("mmap")
            .path

        // 파일 생성 또는 열기
        mmapFD = open(mmapPath, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        guard mmapFD >= 0 else {
            print("Failed to open mmap file")
            return
        }

        // 파일 크기 설정
        ftruncate(mmapFD, off_t(mmapSize))

        // 메모리 매핑
        let ptr = mmap(
            nil,
            mmapSize,
            PROT_READ | PROT_WRITE,
            MAP_SHARED,
            mmapFD,
            0
        )

        guard ptr != MAP_FAILED else {
            print("Failed to mmap")
            close(mmapFD)
            mmapFD = -1
            return
        }

        mmapPtr = ptr
    }

    /// mmap 정리
    private nonisolated func cleanupMmap() {
        if let ptr = mmapPtr {
            munmap(ptr, mmapSize)
            mmapPtr = nil
        }

        if mmapFD >= 0 {
            close(mmapFD)
            mmapFD = -1
        }
    }

    /// 로그 기록
    public func record(_ message: LogMessage) {
        ringBuffer.append(message)
    }

    /// 현재 버퍼를 파일에 저장 (크래시 전 호출)
    public func persist() throws {
        let messages = ringBuffer.toArray()
        guard !messages.isEmpty else { return }

        let data = try encoder.encode(messages)
        try data.write(to: storageURL, options: .atomic)
    }

    /// 저장된 로그 복구 (앱 시작 시 호출)
    public func recover() throws -> [LogMessage]? {
        // 먼저 mmap 크래시 데이터 확인
        if hasCrashData() {
            print("⚠️ Crash detected via mmap")
            clearMmapData()
            // mmap에는 최소 정보만 있으므로 일반 파일도 확인
        }

        guard fm.fileExists(atPath: storageURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: storageURL)
        let messages = try decoder.decode([LogMessage].self, from: data)

        return messages.isEmpty ? nil : messages
    }

    /// 저장된 로그 삭제
    public func clear() throws {
        if fm.fileExists(atPath: storageURL.path) {
            try fm.removeItem(at: storageURL)
        }
        ringBuffer.clear()
    }

    /// 리소스 정리 (수동 호출 필요)
    public func cleanup() {
        cleanupMmap()
    }

    /// 현재 버퍼 내용 확인
    public func currentLogs() -> [LogMessage] {
        ringBuffer.toArray()
    }

    /// 현재 버퍼 크기
    public var count: Int {
        ringBuffer.currentCount
    }

    /// 동기적으로 저장 (Signal Handler용)
    /// - Note: Actor isolation을 우회하므로 주의해서 사용
    /// - Warning: Signal Handler에서만 호출. async-safe 함수만 사용
    public nonisolated func persistSync() {
        // mmap이 초기화되지 않았으면 종료
        guard let ptr = mmapPtr, mmapFD >= 0 else { return }

        // 잠금 획득 (spin lock, signal-safe)
        os_unfair_lock_lock(&syncLock)
        defer { os_unfair_lock_unlock(&syncLock) }

        // 간단한 텍스트 포맷으로 저장 (JSON 인코딩은 signal-safe 아님)
        // 포맷: "CRASH\n타임스탬프\n로그수\n"
        let timestamp = Date().timeIntervalSince1970
        let header = "CRASH\n\(timestamp)\n"

        // 헤더 쓰기
        if let headerData = header.data(using: .utf8) {
            let headerBytes = [UInt8](headerData)
            let headerSize = min(headerBytes.count, mmapSize)
            memcpy(ptr, headerBytes, headerSize)

            // 동기화 (디스크에 즉시 쓰기)
            msync(ptr, mmapSize, MS_SYNC)
        }
    }

    /// mmap에 저장된 크래시 정보 확인
    public nonisolated func hasCrashData() -> Bool {
        guard let ptr = mmapPtr else { return false }

        // "CRASH" 문자열 확인
        let buffer = ptr.assumingMemoryBound(to: UInt8.self)
        let crashMarker = "CRASH\n".utf8

        for (index, byte) in crashMarker.enumerated() {
            if buffer[index] != byte {
                return false
            }
        }

        return true
    }

    /// mmap 데이터 클리어
    public nonisolated func clearMmapData() {
        guard let ptr = mmapPtr else { return }

        os_unfair_lock_lock(&syncLock)
        defer { os_unfair_lock_unlock(&syncLock) }

        // 메모리 초기화
        memset(ptr, 0, mmapSize)
        msync(ptr, mmapSize, MS_SYNC)
    }
}

// MARK: - Signal Handler 등록

public extension CrashLogPreserver {
    /// 크래시 시그널 핸들러 등록
    /// - Note: SIGABRT, SIGSEGV 등 처리
    /// - Parameter preserver: 크래시 로그를 저장할 preserver
    static func registerSignalHandlers(preserver _: CrashLogPreserver) {
        // Actor는 전역 변수로 저장 불가하므로, 약한 참조 사용
        // 실제 프로덕션에서는 전역 mmap 포인터를 직접 사용

        let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL, SIGTRAP]

        for sig in signals {
            signal(sig) { signalNumber in
                // Signal-safe 작업만 수행
                // 1. 크래시 발생 기록 (전역 preserver 접근 필요)
                // 2. 최소한의 정보 저장

                // 주의: 여기서는 preserver에 접근할 수 없음
                // 해결책: 전역 변수나 static 변수 사용

                // 일단 기본 동작으로 종료
                exit(signalNumber)
            }
        }
    }

    /// 전역 preserver를 사용한 Signal Handler 등록
    /// - Note: 더 안전한 방법. mmap 포인터를 직접 사용
    static func registerSignalHandlersUnsafe(
        mmapPtr: UnsafeMutableRawPointer?,
        mmapSize: Int
    ) {
        guard let ptr = mmapPtr else { return }

        // 전역 변수에 저장 (Signal Handler에서 접근)
        crashMmapPtr = ptr
        crashMmapSize = mmapSize

        let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL, SIGTRAP]

        for sig in signals {
            signal(sig) { signalNumber in
                // Signal-safe 작업
                guard let ptr = crashMmapPtr else {
                    exit(signalNumber)
                }

                // "CRASH" 마커 쓰기
                let marker = "CRASH\n"
                _ = marker.withCString { cstr in
                    memcpy(ptr, cstr, min(6, crashMmapSize))
                }

                // 동기화
                msync(ptr, crashMmapSize, MS_SYNC)

                // 종료
                exit(signalNumber)
            }
        }
    }
}

// MARK: - 전역 변수 (Signal Handler용)

private var crashMmapPtr: UnsafeMutableRawPointer?
private var crashMmapSize: Int = 0
