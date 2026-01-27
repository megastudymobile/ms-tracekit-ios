// PerformanceView.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-15.

import SwiftUI

struct PerformanceView: View {
    @StateObject private var viewModel = PerformanceViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                headerSection
                actionsSection
                resultsSection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Performance")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.textPrimary)

            Text("코드 실행 시간을 측정하고 추적하세요")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Performance Tracing")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)

            VStack(spacing: Theme.Spacing.sm) {
                PerformanceActionButton(
                    title: "measure() 시연",
                    subtitle: "단일 작업 시간 측정",
                    icon: "timer",
                    isDisabled: viewModel.isRunning
                ) {
                    Task { await viewModel.runMeasureDemo() }
                }

                PerformanceActionButton(
                    title: "Span 시연",
                    subtitle: "중첩된 작업 추적 (Parent/Child)",
                    icon: "arrow.triangle.branch",
                    isDisabled: viewModel.isRunning
                ) {
                    Task { await viewModel.runSpanDemo() }
                }

                PerformanceActionButton(
                    title: "병렬 작업 시연",
                    subtitle: "TaskGroup을 사용한 병렬 처리",
                    icon: "arrow.triangle.2.circlepath",
                    isDisabled: viewModel.isRunning
                ) {
                    Task { await viewModel.runHeavyOperationDemo() }
                }
                
                Text("Firebase Performance")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.sm)
                
                PerformanceActionButton(
                    title: "Firebase Performance 추적",
                    subtitle: "FirebasePerformanceHelper 사용",
                    icon: "flame.fill",
                    isDisabled: viewModel.isRunning
                ) {
                    Task { await viewModel.runFirebasePerformanceDemo() }
                }
                
                PerformanceActionButton(
                    title: "TraceSpan → Firebase",
                    subtitle: "TraceSpan을 Firebase Performance로 전송",
                    icon: "arrow.up.doc.on.clipboard",
                    isDisabled: viewModel.isRunning
                ) {
                    Task { await viewModel.runSpanWithFirebaseDemo() }
                }
            }

            if viewModel.isRunning {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.accent))
                        .scaleEffect(0.8)

                    Text(viewModel.currentOperation)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Results")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .textCase(.uppercase)

                Spacer()

                if !viewModel.results.isEmpty {
                    Button {
                        viewModel.clearResults()
                    } label: {
                        Text("Clear")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.error)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.results.isEmpty {
                emptyResultsView
            } else {
                ForEach(viewModel.results) { result in
                    ResultRowView(result: result)
                }
            }
        }
    }

    private var emptyResultsView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundColor(Theme.Colors.textTertiary)

            Text("측정 결과가 없습니다")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)

            Text("위의 버튼을 눌러 시연해 보세요")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

// MARK: - Performance Action Button

struct PerformanceActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDisabled ? Theme.Colors.textTertiary : Theme.Colors.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(isDisabled ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)

                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Result Row View

struct ResultRowView: View {
    let result: PerformanceViewModel.MeasurementResult

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: result.timestamp)
    }

    private var durationString: String {
        if result.duration < 1 {
            return String(format: "%.0fms", result.duration * 1000)
        } else {
            return String(format: "%.2fs", result.duration)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(result.name)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text(timeString)
                    .font(Theme.Typography.monoSmall)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            Spacer()

            Text(durationString)
                .font(Theme.Typography.mono)
                .foregroundColor(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.accentMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

#Preview {
    PerformanceView()
}
