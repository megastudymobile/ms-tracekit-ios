// ShoppingFlowDemoView.swift
// TraceKitDemo
//
// Created by jimmy on 2026-01-22.

import SwiftUI
import TraceKit

struct ShoppingFlowDemoView: View {
    @StateObject private var viewModel = ShoppingFlowDemoViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                headerSection
                consoleGuideSection
                flowSelectionSection
                flowVisualizationSection
                firebaseStatusSection
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
                Image(systemName: "cart.fill")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.accent)
                
                Text("Shopping Flow Demo")
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            Text("실무 쇼핑 앱 시뮬레이션 • Firebase 통합 연동")
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
                
                Text("Firebase Console 동시 확인")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("다음 페이지를 동시에 열어두세요:")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                ConsolePageChip(
                    number: 1,
                    title: "Analytics > Realtime",
                    subtitle: "이벤트 실시간 확인"
                )
                
                ConsolePageChip(
                    number: 2,
                    title: "Crashlytics > Dashboard",
                    subtitle: "Breadcrumb 기록 확인"
                )
                
                ConsolePageChip(
                    number: 3,
                    title: "Performance > Custom traces",
                    subtitle: "성능 데이터 확인 (시간 소요)"
                )
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
    }
    
    // MARK: - Flow Selection
    
    private var flowSelectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("쇼핑 플로우 선택")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)
            
            HStack(spacing: Theme.Spacing.sm) {
                FlowButton(
                    title: "정상 플로우",
                    subtitle: "상품 → 장바구니 → 결제 성공",
                    icon: "checkmark.circle.fill",
                    color: Theme.Colors.info,
                    isDisabled: viewModel.isRunning
                ) {
                    Task {
                        await viewModel.startSuccessFlow()
                    }
                }
                
                FlowButton(
                    title: "에러 플로우",
                    subtitle: "상품 → 장바구니 → 결제 실패",
                    icon: "xmark.circle.fill",
                    color: Theme.Colors.error,
                    isDisabled: viewModel.isRunning
                ) {
                    Task {
                        await viewModel.startFailureFlow()
                    }
                }
            }
            
            if viewModel.currentStep != .idle {
                Button {
                    viewModel.reset()
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
    
    // MARK: - Flow Visualization
    
    private var flowVisualizationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("현재 진행 상태")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if viewModel.isRunning {
                    HStack(spacing: Theme.Spacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("실행 중")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            
            VStack(spacing: Theme.Spacing.xs) {
                ForEach([
                    ShoppingStep.browsing,
                    ShoppingStep.addingToCart,
                    ShoppingStep.viewingCart,
                    ShoppingStep.checkout,
                    viewModel.flowType == .success ? ShoppingStep.completed : ShoppingStep.failed
                ], id: \.self) { step in
                    StepRow(
                        step: step,
                        isCurrent: viewModel.currentStep == step,
                        isCompleted: viewModel.currentStep.rawValue > step.rawValue || 
                                    (viewModel.currentStep == .completed || viewModel.currentStep == .failed)
                    )
                }
            }
            
            // 진행률 바
            ProgressView(value: viewModel.progress)
                .tint(viewModel.currentStep == .failed ? Theme.Colors.error : Theme.Colors.accent)
                .padding(.top, Theme.Spacing.sm)
        }
    }
    
    // MARK: - Firebase Status
    
    private var firebaseStatusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(Theme.Colors.accent)
                
                Text("Firebase 전송 상태")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            VStack(spacing: Theme.Spacing.sm) {
                FirebaseServiceCard(
                    icon: "chart.bar.fill",
                    service: "Analytics",
                    status: viewModel.firebaseStatus.analyticsEventCount > 0 ? 
                            "\(viewModel.firebaseStatus.analyticsEventCount)개 이벤트 전송" : 
                            "대기 중",
                    detail: viewModel.firebaseStatus.lastEvent.isEmpty ? 
                            nil : viewModel.firebaseStatus.lastEvent,
                    color: Theme.Colors.info,
                    isActive: viewModel.firebaseStatus.analyticsEventCount > 0
                )
                
                FirebaseServiceCard(
                    icon: "ladybug.fill",
                    service: "Crashlytics",
                    status: "\(viewModel.firebaseStatus.crashlyticsBreadcrumbCount)개 Breadcrumb 기록",
                    detail: viewModel.firebaseStatus.crashlyticsBreadcrumbCount > 0 ? 
                            "백그라운드 전환 후 30초 내 전송" : nil,
                    color: Theme.Colors.warning,
                    isActive: viewModel.firebaseStatus.crashlyticsBreadcrumbCount > 0
                )
                
                FirebaseServiceCard(
                    icon: "timer",
                    service: "Performance",
                    status: viewModel.firebaseStatus.performanceTraceCompleted ? 
                            "Trace 완료" : "대기 중",
                    detail: viewModel.firebaseStatus.performanceTraceCompleted ? 
                            String(format: "%.2f초 소요", viewModel.firebaseStatus.traceDuration ?? 0) : nil,
                    color: Theme.Colors.accent,
                    isActive: viewModel.firebaseStatus.performanceTraceCompleted
                )
            }
            
            if viewModel.currentStep == .completed || viewModel.currentStep == .failed {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(Theme.Colors.accent)
                        
                        Text("다음 단계")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    
                    Text("Firebase Console 3개 탭에서 데이터를 확인하세요:")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        NextStepItem(
                            number: 1,
                            text: "Analytics > Realtime에서 trace_error 확인"
                        )
                        NextStepItem(
                            number: 2,
                            text: "Crashlytics > Dashboard에서 Breadcrumb 확인"
                        )
                        NextStepItem(
                            number: 3,
                            text: "Performance에서 shopping_checkout_flow 확인"
                        )
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }
}

// MARK: - Console Page Chip

struct ConsolePageChip: View {
    let number: Int
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(number)")
                .font(Theme.Typography.mono)
                .foregroundColor(Theme.Colors.background)
                .frame(width: 20, height: 20)
                .background(Theme.Colors.accent)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Flow Button

struct FlowButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(isDisabled ? Theme.Colors.textTertiary : color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(isDisabled ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
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

// MARK: - Step Row

struct StepRow: View {
    let step: ShoppingStep
    let isCurrent: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : step.icon)
                .font(.title3)
                .foregroundColor(stepColor)
                .frame(width: 24)
            
            Text(step.rawValue)
                .font(Theme.Typography.body)
                .foregroundColor(isCurrent ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
            
            Spacer()
            
            if isCurrent {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(Theme.Spacing.md)
        .background(isCurrent ? Theme.Colors.surface : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
    
    private var stepColor: Color {
        if step == .failed {
            return Theme.Colors.error
        } else if step == .completed {
            return Theme.Colors.info
        } else if isCurrent {
            return Theme.Colors.accent
        } else if isCompleted {
            return Theme.Colors.info
        } else {
            return Theme.Colors.textTertiary
        }
    }
}

// MARK: - Firebase Service Card

struct FirebaseServiceCard: View {
    let icon: String
    let service: String
    let status: String
    let detail: String?
    let color: Color
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isActive ? color : Theme.Colors.textTertiary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(service)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(status)
                    .font(Theme.Typography.caption)
                    .foregroundColor(isActive ? color : Theme.Colors.textTertiary)
                
                if let detail = detail {
                    Text(detail)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(color)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(color.opacity(isActive ? 0.3 : 0), lineWidth: 1)
        )
    }
}

// MARK: - Next Step Item

struct NextStepItem: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(number)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
                .frame(width: 16)
            
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

#Preview {
    ShoppingFlowDemoView()
}
