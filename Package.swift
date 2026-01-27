// swift-tools-version: 6.0
// Package.swift
// TraceKit
//
// Created by jimmy on 2024-12-18.

import PackageDescription

let package = Package(
    name: "TraceKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        // 코어 TraceKit 프레임워크
        .library(
            name: "TraceKit",
            targets: ["TraceKit"]
        )
    ],
    dependencies: [],
    targets: [
        // MARK: - Core TraceKit Target
        .target(
            name: "TraceKit",
            dependencies: [],
            path: "Projects/TraceKit/Sources",
            exclude: [
                "Crash/CRASH_PRESERVER_GUIDE.md"
            ]
        ),
        
        // MARK: - TraceKit Tests
        .testTarget(
            name: "TraceKitTests",
            dependencies: ["TraceKit"],
            path: "Projects/TraceKit/Tests"
        )
    ]
)
