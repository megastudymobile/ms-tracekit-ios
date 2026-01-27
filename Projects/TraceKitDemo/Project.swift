// Project.swift
// TraceKitDemo
//
// Created by jimmy on 2025-12-18.

import ProjectDescription

let project = Project(
    name: "TraceKitDemo",
    organizationName: "com.tracekit",
    packages: [
        .local(path: .relativeToRoot("../.."))
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
            resources: ["Resources/**"],
            entitlements: "Resources/TraceKitDemo.entitlements",
            scripts: [
                .post(
                    script: """
                    # Firebase Crashlytics dSYM 업로드 스크립트
                    # Debug 빌드에서도 실행하여 심볼화된 크래시 리포트 확인
                    echo "🔥 Firebase Crashlytics dSYM 업로드 (${CONFIGURATION} 빌드)"
                    echo "📱 GoogleService-Info.plist: ${SRCROOT}/Resources/GoogleService-Info.plist"
                    echo "📱 CONFIGURATION: ${CONFIGURATION}"

                    # GoogleService-Info.plist 파일 경로
                    GOOGLE_SERVICE_PLIST="${SRCROOT}/Resources/GoogleService-Info.plist"

                    # GoogleService-Info.plist 파일 존재 확인
                    if [ ! -f "$GOOGLE_SERVICE_PLIST" ]; then
                        echo "⚠️ GoogleService-Info.plist 파일을 찾을 수 없습니다"
                        echo "⚠️ dSYM 업로드를 건너뜁니다"
                        exit 0
                    fi

                    # Firebase Crashlytics 스크립트 경로 (Tuist 프로젝트 구조)
                    # Tuist는 SPM 패키지를 Tuist/.build/checkouts/ 경로에 저장
                    SCRIPT_PATH="${SRCROOT}/Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/run"

                    if [ ! -f "$SCRIPT_PATH" ]; then
                        echo "⚠️ Firebase Crashlytics script not found at $SCRIPT_PATH"
                        echo "⚠️ dSYM 업로드를 건너뜁니다"
                        exit 0
                    fi

                    # GOOGLE_APP_ID 추출
                    if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
                        GOOGLE_APP_ID=$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$GOOGLE_SERVICE_PLIST" 2>/dev/null)
                        if [ -n "$GOOGLE_APP_ID" ]; then
                            echo "🆔 GOOGLE_APP_ID: ${GOOGLE_APP_ID}"
                        fi
                    fi

                    # Firebase Crashlytics 스크립트 실행
                    echo "📤 dSYM 파일 업로드 중..."
                    "$SCRIPT_PATH" -gsp "$GOOGLE_SERVICE_PLIST"

                    # 업로드 완료 마커 생성
                    echo "uploaded" > "${TARGET_BUILD_DIR}/.crashlytics_dsym_upload_marker"
                    echo "✅ Firebase Crashlytics dSYM 업로드 완료!"
                    """,
                    name: "Upload dSYM to Firebase Crashlytics",
                    inputPaths: [
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}",
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}",
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist",
                        "$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist",
                        "$(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)"
                    ],
                    outputPaths: [
                        "$(TARGET_BUILD_DIR)/.crashlytics_dsym_upload_marker"
                    ]
                )
            ],
            dependencies: [
                .package(product: "TraceKit", type: .runtime),
                .external(name: "FirebaseCrashlytics"),
                .external(name: "FirebaseAnalytics"),
                .external(name: "FirebasePerformance"),
                .external(name: "FirebaseRemoteConfig")
            ],
            settings: .settings(
                base: [
                    "DEVELOPMENT_TEAM": "",
                    "CODE_SIGN_STYLE": "Automatic",
                    "CODE_SIGN_ENTITLEMENTS": "Resources/TraceKitDemo.entitlements",
                    "ENABLE_PREVIEWS": "YES",
                    "SWIFT_VERSION": "5.10",
                    "TARGETED_DEVICE_FAMILY": "1,2",
                    // Firebase 필수 링커 플래그 - Objective-C 카테고리 메서드 링크
                    "OTHER_LDFLAGS": "$(inherited) -ObjC",
                    // dSYM 파일 항상 생성 (Crashlytics 심볼 업로드용)
                    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym"
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
            runAction: .runAction(
                configuration: .debug,
                arguments: .arguments(
                    launchArguments: [
                        .launchArgument(name: "-FIRDebugEnabled", isEnabled: true),
                        .launchArgument(name: "-FIRAnalyticsDebugEnabled", isEnabled: true)
                    ]
                )
            ),
            archiveAction: .archiveAction(configuration: .release)
        )
    ]
)

