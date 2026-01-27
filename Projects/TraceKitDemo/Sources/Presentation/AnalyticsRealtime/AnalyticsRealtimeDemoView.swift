// AnalyticsRealtimeDemoView.swift
// TraceKitDemo
//
// Created by jimmy on 2026-01-22.

import SwiftUI
import TraceKit

struct AnalyticsRealtimeDemoView: View {
    @StateObject private var viewModel = AnalyticsRealtimeDemoViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                headerSection
                consoleGuideSection
                scenarioSection
                userContextSection
                eventHistorySection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.accent)
                
                Text("Analytics Realtime Demo")
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            Text("Firebase Console에서 즉시 확인 가능한 이벤트 전송")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Console Guide
    
    private var consoleGuideSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Theme.Colors.accent)
                
                Text("Firebase Console 확인 가이드")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                GuideStep(number: 1, text: "Firebase Console 열기")
                GuideStep(number: 2, text: "Analytics > Realtime 클릭")
                GuideStep(number: 3, text: "아래 시나리오 버튼 클릭")
                GuideStep(number: 4, text: "Console에서 이벤트 즉시 확인! 🎉")
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
    }
    
    // MARK: - Scenarios
    
    private var scenarioSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("시나리오 실행")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)
            
            VStack(spacing: Theme.Spacing.sm) {
                ScenarioButton(
                    title: "네트워크 에러 발생",
                    subtitle: "trace_error • Network",
                    icon: "wifi.exclamationmark",
                    color: Theme.Colors.error
                ) {
                    viewModel.sendNetworkError()
                }
                
                ScenarioButton(
                    title: "결제 실패",
                    subtitle: "trace_error • Payment",
                    icon: "creditcard.trianglebadge.exclamationmark",
                    color: Theme.Colors.error
                ) {
                    viewModel.sendPaymentFailure()
                }
                
                ScenarioButton(
                    title: "크래시 발생",
                    subtitle: "trace_fatal • Database",
                    icon: "exclamationmark.triangle.fill",
                    color: Theme.Colors.fatal
                ) {
                    viewModel.sendFatalCrash()
                }
                
                ScenarioButton(
                    title: "사용자 로그아웃 에러",
                    subtitle: "trace_error • Auth",
                    icon: "person.crop.circle.badge.xmark",
                    color: Theme.Colors.error
                ) {
                    viewModel.sendLogoutError()
                }
            }
        }
    }
    
    // MARK: - User Context
    
    private var userContextSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "person.text.rectangle")
                    .foregroundColor(Theme.Colors.accent)
                
                Text("User Context 설정")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            VStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("User ID")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    TextField("예: user_12345", text: $viewModel.userId)
                        .font(Theme.Typography.mono)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("User Plan")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    TextField("예: premium", text: $viewModel.userPlan)
                        .font(Theme.Typography.mono)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )
                }
                
                Button {
                    Task {
                        await viewModel.applyUserContext()
                    }
                } label: {
                    HStack {
                        if viewModel.isApplyingContext {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("User Context 적용")
                    }
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.background)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isApplyingContext)
                
                if let userId = viewModel.lastAppliedUserId,
                   let plan = viewModel.lastAppliedPlan {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.Colors.info)
                            .font(.caption)
                        
                        Text("적용됨: \(userId) • \(plan)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            
            Text("→ Console에서 User Properties 확인!")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.accent)
                .padding(.leading, Theme.Spacing.sm)
        }
    }
    
    // MARK: - Event History
    
    private var eventHistorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("전송 이력")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if !viewModel.eventHistory.isEmpty {
                    Button {
                        viewModel.clearHistory()
                    } label: {
                        Text("지우기")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            
            if viewModel.eventHistory.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text("아직 전송된 이벤트가 없습니다")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xl)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(viewModel.eventHistory) { record in
                        EventHistoryRow(record: record)
                    }
                }
            }
        }
    }
}

// MARK: - Guide Step

struct GuideStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(number)")
                .font(Theme.Typography.mono)
                .foregroundColor(Theme.Colors.background)
                .frame(width: 24, height: 24)
                .background(Theme.Colors.accent)
                .clipShape(Circle())
            
            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
        }
    }
}

// MARK: - Scenario Button

struct ScenarioButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                
                Spacer()
                
                Image(systemName: "paperplane.fill")
                    .font(.caption)
                    .foregroundColor(color)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event History Row

struct EventHistoryRow: View {
    let record: AnalyticsEventRecord
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(Theme.Colors.info)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(record.timeString)
                        .font(Theme.Typography.monoSmall)
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text("•")
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text(record.eventName)
                        .font(Theme.Typography.mono)
                        .foregroundColor(record.level.color)
                    
                    Text("전송 완료")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                HStack(spacing: Theme.Spacing.xs) {
                    Text("└")
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text("category:")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text(record.category)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                HStack(spacing: Theme.Spacing.xs) {
                    Text("└")
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text("message:")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text(record.message)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

#Preview {
    AnalyticsRealtimeDemoView()
}
