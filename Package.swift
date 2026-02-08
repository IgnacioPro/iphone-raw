// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "photodew",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "App", targets: ["App"]),
        .library(name: "CameraKit", targets: ["CameraKit"]),
        .library(name: "CaptureUI", targets: ["CaptureUI"]),
        .library(name: "RenderKit", targets: ["RenderKit"]),
        .library(name: "Storage", targets: ["Storage"]),
    ],
    targets: [
        .target(
            name: "CameraKit"
        ),
        .target(
            name: "Storage"
        ),
        .target(
            name: "RenderKit",
            dependencies: [
                "CameraKit",
            ]
        ),
        .target(
            name: "App",
            dependencies: [
                "CameraKit",
                "RenderKit",
                "Storage",
            ]
        ),
        .target(
            name: "CaptureUI",
            dependencies: [
                "App",
                "CameraKit",
            ]
        ),
        .testTarget(
            name: "CameraKitTests",
            dependencies: ["CameraKit"]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                "App",
                "CameraKit",
            ]
        ),
        .testTarget(
            name: "RenderKitTests",
            dependencies: ["RenderKit"]
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage"]
        ),
    ]
)
