// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "NFOCore",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "NFOCore", targets: ["NFOCore"])
    ],
    targets: [
        .target(
            name: "NFOCore",
            path: "Sources",
            exclude: [
                "AppDelegate.swift",
                "Document.swift",
                "PreferencesViewController.swift",
                "ThemeAwareScrollView.swift",
                "ThemeManager.swift",
                "ViewController.swift"
            ],
            sources: [
                "Constants.swift",
                "NFOContentDecoder.swift",
                "NFOLayoutPolicy.swift"
            ]
        ),
        .testTarget(
            name: "NFOCoreTests",
            dependencies: ["NFOCore"],
            path: "Tests/NFOCoreTests"
        )
    ]
)
