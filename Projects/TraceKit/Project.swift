// Project.swift
// TraceKit
//
// Created by jimmy on 2025-12-15.

import ProjectDescription

let project = Project(
    name: "TraceKit",
    organizationName: "com.tracekit",
    targets: [
        .target(
            name: "TraceKit",
            destinations: [.iPhone, .iPad, .mac, .appleWatch, .appleTv, .appleVision],
            product: .framework,
            bundleId: "com.tracekit.TraceKit",
            deploymentTargets: .multiplatform(
                iOS: "15.0",
                macOS: "12.0",
                watchOS: "8.0",
                tvOS: "15.0",
                visionOS: "1.0"
            ),
            infoPlist: .default,
            sources: ["Sources/**"],
            dependencies: []
        ),
        .target(
            name: "TraceKitTests",
            destinations: [.iPhone, .iPad],
            product: .unitTests,
            bundleId: "com.tracekit.TraceKitTests",
            deploymentTargets: .iOS("15.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "TraceKit")
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "TraceKit",
            shared: true,
            buildAction: .buildAction(targets: ["TraceKit", "TraceKitTests"]),
            testAction: .targets(
                [.testableTarget(target: "TraceKitTests")],
                options: .options(coverage: true, codeCoverageTargets: ["TraceKit"])
            ),
            runAction: .runAction(configuration: .debug),
            archiveAction: .archiveAction(configuration: .release)
        )
    ]
)
