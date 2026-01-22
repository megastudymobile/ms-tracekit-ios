// TraceStream.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-15.

import Combine
import Foundation
import TraceKit

@MainActor
final class TraceStream: ObservableObject {
    static let shared = TraceStream()

    @Published private(set) var logs: [TraceMessage] = []

    private let maxLogs: Int

    private init(maxLogs: Int = 500) {
        self.maxLogs = maxLogs
    }

    func append(_ message: TraceMessage) {
        logs.append(message)

        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }

    func append(contentsOf messages: [TraceMessage]) {
        for message in messages {
            append(message)
        }
    }

    func clear() {
        logs.removeAll()
    }
}
