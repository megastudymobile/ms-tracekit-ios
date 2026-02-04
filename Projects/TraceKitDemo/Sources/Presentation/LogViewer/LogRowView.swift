// LogRowView.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-15.

import SwiftUI
import TraceKit

struct LogRowView: View {
    let message: TraceMessage
    @State private var isExpanded: Bool = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: message.timestamp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            HStack(spacing: Theme.Spacing.sm) {
                TraceLevelBadge(level: message.level)

                Text(message.category)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)

                Spacer()

                Text(timeString)
                    .font(Theme.Typography.monoSmall)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            // Message
            Text(message.message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(isExpanded ? nil : 2)

            // Details (expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Divider()
                        .background(Theme.Colors.divider)

                    DetailRow(label: "File", value: message.fileName)
                    DetailRow(label: "Function", value: message.function)
                    DetailRow(label: "Line", value: "\(message.line)")

                    if let metadata = message.metadata, !metadata.isEmpty {
                        Text("Metadata")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                            .padding(.top, Theme.Spacing.xs)

                        ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                            if let value = metadata[key] {
                                DetailRow(label: key, value: "\(value)")
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(message.level.color.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(Theme.Typography.mono)
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(3)
        }
    }
}

#Preview {
    VStack {
        LogRowView(message: TraceMessage(
            level: .info,
            message: "사용자가 로그인했습니다",
            category: "Auth",
            file: "LoginViewController.swift",
            function: "loginButtonTapped()",
            line: 42
        ))

        LogRowView(message: TraceMessage(
            level: .error,
            message: "네트워크 요청 실패: Connection timeout",
            category: "Network",
            metadata: ["statusCode": AnyCodable(500), "url": AnyCodable("/api/users")],  // Preview: 기존 API 사용
            file: "APIClient.swift",
            function: "request()",
            line: 128
        ))
    }
    .padding()
    .background(Theme.Colors.background)
}
