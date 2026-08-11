// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Kuati",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Kuati", targets: ["Kuati"]),
        .executable(name: "KuatiLayoutTests", targets: ["KuatiLayoutTests"])
    ],
    targets: [
        .target(name: "KuatiCore"),
        .executableTarget(name: "Kuati", dependencies: ["KuatiCore"]),
        .executableTarget(
            name: "KuatiLayoutTests",
            dependencies: ["KuatiCore"],
            path: "Tests/KuatiLayoutTests"
        )
    ]
)
