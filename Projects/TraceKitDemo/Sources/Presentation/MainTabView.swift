// MainTabView.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-15.

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .analyticsRealtime

    enum Tab: String, CaseIterable {
        case analyticsRealtime
        case remoteConfig
        case crashlyticsRealtime
        case shoppingFlow
        case generator
        case settings
        case viewer
        case performance
        case sanitizer
        case crash

        var title: String {
            switch self {
            case .analyticsRealtime: return "Analytics"
            case .remoteConfig: return "Config"
            case .crashlyticsRealtime: return "Crashlytics"
            case .shoppingFlow: return "Shopping"
            case .generator: return "Generator"
            case .settings: return "Settings"
            case .viewer: return "Viewer"
            case .performance: return "Performance"
            case .sanitizer: return "Sanitizer"
            case .crash: return "Crash"
            }
        }

        var icon: String {
            switch self {
            case .analyticsRealtime: return "chart.bar"
            case .remoteConfig: return "slider.horizontal.3"
            case .crashlyticsRealtime: return "ladybug"
            case .shoppingFlow: return "cart"
            case .generator: return "play.circle"
            case .settings: return "gearshape"
            case .viewer: return "list.bullet.rectangle"
            case .performance: return "timer"
            case .sanitizer: return "lock.shield"
            case .crash: return "exclamationmark.triangle"
            }
        }

        var selectedIcon: String {
            switch self {
            case .analyticsRealtime: return "chart.bar.fill"
            case .remoteConfig: return "slider.horizontal.3"
            case .crashlyticsRealtime: return "ladybug.fill"
            case .shoppingFlow: return "cart.fill"
            case .generator: return "play.circle.fill"
            case .settings: return "gearshape.fill"
            case .viewer: return "list.bullet.rectangle.fill"
            case .performance: return "timer"
            case .sanitizer: return "lock.shield.fill"
            case .crash: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            AnalyticsRealtimeDemoView()
                .tag(Tab.analyticsRealtime)
                .tabItem {
                    Label(Tab.analyticsRealtime.title, systemImage: selectedTab == .analyticsRealtime ? Tab.analyticsRealtime.selectedIcon : Tab.analyticsRealtime.icon)
                }

            RemoteConfigControlView()
                .tag(Tab.remoteConfig)
                .tabItem {
                    Label(Tab.remoteConfig.title, systemImage: selectedTab == .remoteConfig ? Tab.remoteConfig.selectedIcon : Tab.remoteConfig.icon)
                }

            CrashlyticsRealtimeDemoView()
                .tag(Tab.crashlyticsRealtime)
                .tabItem {
                    Label(Tab.crashlyticsRealtime.title, systemImage: selectedTab == .crashlyticsRealtime ? Tab.crashlyticsRealtime.selectedIcon : Tab.crashlyticsRealtime.icon)
                }

            ShoppingFlowDemoView()
                .tag(Tab.shoppingFlow)
                .tabItem {
                    Label(Tab.shoppingFlow.title, systemImage: selectedTab == .shoppingFlow ? Tab.shoppingFlow.selectedIcon : Tab.shoppingFlow.icon)
                }

            LogGeneratorView()
                .tag(Tab.generator)
                .tabItem {
                    Label(Tab.generator.title, systemImage: selectedTab == .generator ? Tab.generator.selectedIcon : Tab.generator.icon)
                }

            SettingsView()
                .tag(Tab.settings)
                .tabItem {
                    Label(Tab.settings.title, systemImage: selectedTab == .settings ? Tab.settings.selectedIcon : Tab.settings.icon)
                }

            LogViewerView()
                .tag(Tab.viewer)
                .tabItem {
                    Label(Tab.viewer.title, systemImage: selectedTab == .viewer ? Tab.viewer.selectedIcon : Tab.viewer.icon)
                }

            PerformanceView()
                .tag(Tab.performance)
                .tabItem {
                    Label(Tab.performance.title, systemImage: selectedTab == .performance ? Tab.performance.selectedIcon : Tab.performance.icon)
                }

            SanitizerDemoView()
                .tag(Tab.sanitizer)
                .tabItem {
                    Label(Tab.sanitizer.title, systemImage: selectedTab == .sanitizer ? Tab.sanitizer.selectedIcon : Tab.sanitizer.icon)
                }

            CrashDemoView()
                .tag(Tab.crash)
                .tabItem {
                    Label(Tab.crash.title, systemImage: selectedTab == .crash ? Tab.crash.selectedIcon : Tab.crash.icon)
                }
        }
        .tint(Theme.Colors.accent)
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
