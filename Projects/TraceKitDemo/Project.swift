// Project.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-18.

import ProjectDescription

let project = Project(
    name: "TraceKitDemo",
    organizationName: "com.tracekit",
    packages: [
        .local(path: .relativeToRoot("../../"))
    ],
    targets: [
        .target(
            name: "TraceKitDemo",
            destinations: .iOS,
            product: .app,
            bundleId: "com.tracekit.TraceKitDemo",
            deploymentTargets: .iOS("15.0"),
            infoPlist: .extendingDefault(
                with: [
                    "UIApplicationSceneManifest": [
                        "UIApplicationSupportsMultipleScenes": false,
                        "UISceneConfigurations": [
                            "UIWindowSceneSessionRoleApplication": [
                                [
                                    "UISceneConfigurationName": "Default Configuration",
                                    "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate"
                                ]
                            ]
                        ]
                    ],
                    "UILaunchScreen": [:],
                    "UISupportedInterfaceOrientations": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight"
                    ],
                    "UISupportedInterfaceOrientations~ipad": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationPortraitUpsideDown",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight"
                    ]
                ]
            ),
            sources: ["Sources/**"],
            dependencies: [
                .package(product: "TraceKit", type: .runtime)
            ],
            settings: .settings(
                base: [
                    "DEVELOPMENT_TEAM": "",
                    "CODE_SIGN_STYLE": "Automatic",
                    "ENABLE_PREVIEWS": "YES",
                    "SWIFT_VERSION": "6.0",
                    "TARGETED_DEVICE_FAMILY": "1,2"
                ],
                configurations: [
                    .debug(name: .debug),
                    .release(name: .release)
                ]
            )
        )
    ],
    schemes: [
        .scheme(
            name: "TraceKitDemo",
            shared: true,
            buildAction: .buildAction(targets: ["TraceKitDemo"]),
            runAction: .runAction(configuration: .debug),
            archiveAction: .archiveAction(configuration: .release)
        )
    ]
)

