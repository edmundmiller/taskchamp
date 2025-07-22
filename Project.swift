import ProjectDescription

let project = Project(
    name: "taskchamp",
    settings: .settings(base: [
        "SWIFT_OBJC_INTEROP_MODE": "objcxx",
        "SWIFT_INCLUDE_PATHS": ["$(PROJECT_DIR)"],
        "CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION": "YES"
    ], defaultSettings: .recommended),
    targets: [
        .target(
            name: "taskchamp",
            destinations: .iOS,
            product: .app,
            bundleId: "com.edmundmiller.taskchamp",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleName": "Taskchamp",
                    "UILaunchScreen": [
                        "UIColorName": "LaunchBackground"
                    ],
                    "NSAccentColorName": "AccentColor",
                    "ITSAppUsesNonExemptEncryption": false,
                    // iCloud container requires paid Apple Developer account
                    // "NSUbiquitousContainers": [
                    //     "iCloud.com.mav.taskchamp":
                    //         [
                    //             "NSUbiquitousContainerIsDocumentScopePublic": true,
                    //             "NSUbiquitousContainerName": "taskchamp",
                    //             "NSUbiquitousContainerSupportedFolderLevels": "Any"
                    //         ]
                    // ],
                    "CFBundleShortVersionString": "1.3"
                ]
            ),
            sources: ["taskchamp/Sources/**"],
            resources: ["taskchamp/Resources/**"],
            entitlements: .dictionary(
                [:]
                // iCloud and time-sensitive notifications require paid Apple Developer account
                // "com.apple.developer.icloud-container-identifiers": ["iCloud.com.mav.taskchamp"],
                // "com.apple.developer.icloud-services": ["CloudDocuments", "CloudKit"],
                // "com.apple.developer.ubiquity-container-identifiers": ["iCloud.com.mav.taskchamp"],
                // "com.apple.developer.usernotifications.time-sensitive": true
            ),
            scripts: [
                .pre(script: "./scripts/pre_build_script.sh", name: "Prebuild", basedOnDependencyAnalysis: false)
            ],
            dependencies: [
                .target(name: "taskchampShared")
                // .target(name: "taskchampWidget") // Temporarily disabled due to build issues
            ]
        ),
        .target(
            name: "taskchampTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.edmundmiller.taskchamp.taskchampTests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["taskchamp/Tests/**"],
            resources: [],
            dependencies: [.target(name: "taskchamp")]
        ),
        .target(
            name: "taskchampWidget",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "com.edmundmiller.taskchamp.taskchampWidget",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "$(PRODUCT_NAME)",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
                ],
                // iCloud container requires paid Apple Developer account
                // "NSUbiquitousContainers": [
                //     "iCloud.com.mav.taskchamp":
                //         [
                //             "NSUbiquitousContainerIsDocumentScopePublic": true,
                //             "NSUbiquitousContainerName": "taskchamp",
                //             "NSUbiquitousContainerSupportedFolderLevels": "Any"
                //         ]
                // ],
                "CFBundleShortVersionString": "1.3"
            ]),
            sources: "taskchampWidget/Sources/**",
            entitlements: .dictionary(
                [:]
                // iCloud capabilities require paid Apple Developer account
                // "com.apple.developer.icloud-container-identifiers": ["iCloud.com.mav.taskchamp"],
                // "com.apple.developer.icloud-services": ["CloudDocuments"],
                // "com.apple.developer.ubiquity-container-identifiers": ["iCloud.com.mav.taskchamp"]
            ),
            dependencies: [
                .target(name: "taskchampShared")
            ]
        ),
        .target(
            name: "taskchampShared",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.edmundmiller.taskchamp.taskchampShared",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: "taskchampShared/Sources/**",
            dependencies: [
                .external(name: "SQLite"),
                .external(name: "SoulverCore")
                // .external(name: "Taskchampion") // Temporarily disabled - API incompatible
            ]
        )
    ]
)
