// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchDrop",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "NotchDrop",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
