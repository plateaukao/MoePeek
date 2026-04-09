import ProjectDescription

let project = Project(
    name: "MoePeek",
    settings: .settings(
        base: [
            "INFOPLIST_KEY_LSUIElement": "YES",
            "INFOPLIST_KEY_NSAccessibilityUsageDescription":
                "MoePeek needs accessibility access to read selected text.",
            "SWIFT_STRICT_CONCURRENCY": "complete",
        ],
        configurations: [
            .debug(name: "Debug", xcconfig: "Configurations/Signing.xcconfig"),
            .release(name: "Release", xcconfig: "Configurations/Signing.xcconfig"),
        ]
    ),
    targets: [
        .target(
            name: "MoePeek",
            destinations: .macOS,
            product: .app,
            bundleId: "com.nahida.MoePeek",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDevelopmentRegion": "en",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleURLTypes": [
                    [
                        "CFBundleURLName": "com.nahida.MoePeek",
                        "CFBundleURLSchemes": ["mopeek"],
                    ],
                ],
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            entitlements: .file(path: "Entitlements/MoePeek.entitlements"),
            dependencies: [
                .external(name: "KeyboardShortcuts"),
                .external(name: "Defaults"),
            ],
            settings: .settings(
                base: [
                    "CODE_SIGN_STYLE": "$(MOEPEEK_CODE_SIGN_STYLE)",
                    "CODE_SIGN_IDENTITY": "$(MOEPEEK_CODE_SIGN_IDENTITY)",
                    "DEVELOPMENT_TEAM": "$(MOEPEEK_DEVELOPMENT_TEAM)",
                    "MARKETING_VERSION": "0.13.1",
                    "CURRENT_PROJECT_VERSION": "1",
                ],
                configurations: [
                    .debug(name: "Debug", xcconfig: "Configurations/Signing.xcconfig"),
                    .release(name: "Release", xcconfig: "Configurations/Signing.xcconfig"),
                ]
            )
        ),
    ]
)
