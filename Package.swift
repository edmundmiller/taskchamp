// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TaskChamp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "taskchampShared",
            targets: ["taskchampShared"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1"),
        .package(url: "https://github.com/SoulverTeam/SoulverCore.git", from: "2.0.0"),
        .package(path: "./Dependencies/taskchampion-swift"),
    ],
    targets: [
        .target(
            name: "taskchampShared",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "SoulverCore", package: "SoulverCore"),
                .product(name: "Taskchampion", package: "taskchampion-swift")
            ],
            path: "taskchampShared/Sources"
        ),
        .testTarget(
            name: "TaskChampTests",
            dependencies: ["taskchampShared"],
            path: "Tests",
            sources: [
                "E2E_AWS_Sync_Test.swift",
                "E2E_R2_Sync_Test.swift",
                "TaskChampionIntegrationTest.swift"
            ]
        ),
    ]
)
