// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Usb8RestoreSwift",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "usb8-restore", targets: ["Usb8RestoreSwift"])
    ],
    targets: [
        .executableTarget(
            name: "Usb8RestoreSwift",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "Usb8RestoreSwiftTests",
            dependencies: ["Usb8RestoreSwift"]
        )
    ]
)
