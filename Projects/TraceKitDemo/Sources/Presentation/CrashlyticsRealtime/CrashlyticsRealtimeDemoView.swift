// CrashlyticsRealtimeDemoView.swift
// TraceKitDemo
//
// Created by jimmy on 2026-01-22.

import SwiftUI
import TraceKit

struct CrashlyticsRealtimeDemoView: View {
    @StateObject private var viewModel = CrashlyticsRealtimeDemoViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                headerSection
                consoleGuideSection
                scenarioSelectionSection
                breadcrumbTimelineSection
                controlSection
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
                Image(systemName: "ladybug.fill")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.accent)
                
                Text("Crashlytics Breadcrumb")
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            Text("크래시 발생 전 사용자 행동 추적")
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
                CrashlyticsGuideStep(number: 1, text: "아래 시나리오 실행")
                CrashlyticsGuideStep(number: 2, text: "에러 발생 후 자동으로 Crashlytics에 전송됨")
                CrashlyticsGuideStep(number: 3, text: "Firebase Console 열기")
                CrashlyticsGuideStep(number: 4, text: "Crashlytics > Dashboard 클릭")
                CrashlyticsGuideStep(number: 5, text: "Non-fatal 에러 확인! 🎉")
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.Colors.info)
                    .font(.caption)
                
                Text("Debug 모드: 에러 발생 즉시 Firebase에 전송됩니다 (백그라운드 불필요)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.info.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
    }
    
    // MARK: - Scenario Selection
    
    private var scenarioSelectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("크래시 재현 시나리오")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)
            
            VStack(spacing: Theme.Spacing.sm) {
                CrashlyticsScenarioButton(
                    title: "쇼핑 결제 실패",
                    subtitle: "장바구니 → 결제 → 에러",
                    icon: "cart.badge.minus",
                    color: Theme.Colors.error,
                    isDisabled: viewModel.scenarioState != .idle
                ) {
                    Task {
                        await viewModel.startShoppingScenario()
                    }
                }
                
                CrashlyticsScenarioButton(
                    title: "로그인 실패",
                    subtitle: "앱 시작 → 로그인 → 인증 에러",
                    icon: "person.crop.circle.badge.xmark",
                    color: Theme.Colors.error,
                    isDisabled: viewModel.scenarioState != .idle
                ) {
                    Task {
                        await viewModel.startLoginFailureScenario()
                    }
                }
                
                CrashlyticsScenarioButton(
                    title: "데이터 로딩 크래시",
                    subtitle: "데이터 로딩 → 파싱 → Fatal",
                    icon: "exclamationmark.triangle.fill",
                    color: Theme.Colors.fatal,
                    isDisabled: viewModel.scenarioState != .idle
                ) {
                    Task {
                        await viewModel.startDataCrashScenario()
                    }
                }
            }
        }
    }
    
    // MARK: - Breadcrumb Timeline
    
    private var breadcrumbTimelineSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Breadcrumb 타임라인")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text(viewModel.scenarioState.displayText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(stateColor)
            }
            
            if viewModel.breadcrumbs.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "timeline.selection")
                        .font(.largeTitle)
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text("시나리오를 선택하면 Breadcrumb이 기록됩니다")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xl)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(viewModel.breadcrumbs) { breadcrumb in
                        BreadcrumbRow(breadcrumb: breadcrumb)
                    }
                }
            }
        }
    }
    
    // MARK: - Control
    
    private var controlSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if viewModel.scenarioState == .waitingForBackground {
                VStack(spacing: Theme.Spacing.sm) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.Colors.info)
                        
                        Text("에러 전송 완료!")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.info)
                    }
                    
                    Text("Firebase Console > Crashlytics > Dashboard에서 Non-fatal 에러와 Breadcrumb을 확인하세요")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.info.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            
            if viewModel.scenarioState != .idle {
                Button {
                    viewModel.resetScenario()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("초기화")
                    }
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var stateColor: Color {
        switch viewModel.scenarioState {
        case .idle: return Theme.Colors.textTertiary
        case .running: return Theme.Colors.info
        case .waitingForBackground: return Theme.Colors.warning
        case .completed: return Theme.Colors.info
        }
    }
}

// MARK: - Crashlytics Guide Step

struct CrashlyticsGuideStep: View {
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

// MARK: - Crashlytics Scenario Button

struct CrashlyticsScenarioButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDisabled ? Theme.Colors.textTertiary : color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(isDisabled ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(isDisabled ? Theme.Colors.textTertiary : color)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(color.opacity(isDisabled ? 0.1 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Breadcrumb Row

struct BreadcrumbRow: View {
    let breadcrumb: BreadcrumbEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Circle()
                .fill(breadcrumb.level.color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(breadcrumb.timeString)
                        .font(Theme.Typography.monoSmall)
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text("•")
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text("[\(breadcrumb.level.name)]")
                        .font(Theme.Typography.mono)
                        .foregroundColor(breadcrumb.level.color)
                    
                    Text("[\(breadcrumb.category)]")
                        .font(Theme.Typography.mono)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                Text(breadcrumb.message)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

#Preview {
    CrashlyticsRealtimeDemoView()
}
