// swift-tools-version: 6.0
// Tuist/Package.swift
// TraceKitDemo
//
// Created by jimmy on 2025-01-22.

import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [
            "FirebaseAnalytics": .staticLibrary,
            "FirebaseCrashlytics": .staticLibrary,
            "FirebaseRemoteConfig": .staticLibrary,
            "FirebasePerformance": .staticLibrary
        ]
    )
#endif

let package = Package(
    name: "TraceKitDemo",
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk",
            from: "11.0.0"
        )
    ]
)
