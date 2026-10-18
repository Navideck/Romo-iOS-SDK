// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Romo",
    platforms: [
        .iOS("15.5"),
    ],
    products: [
        .library(name: "RMShared", targets: ["RMShared"]),
        .library(name: "RMCore", targets: ["RMCore"]),
        .library(name: "RMCharacter", targets: ["RMCharacter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.8.0"),
    ],
    targets: [
        .target(
            name: "RMShared",
            dependencies: [
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ],
            path: "RMShared/Classes",
            exclude: [
                "RMShared-Prefix.pch",
                // The web socket logger depends on SocketRocket, which doesn't support SwiftPM
                "lib/Loggers/RMWebSocketLogger.h",
                "lib/Loggers/RMWebSocketLogger.m",
                "lib/Web Socket",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include/Romo"),
                .headerSearchPath("Data Structures"),
                .headerSearchPath("lib/Categories"),
            ]
        ),
        .target(
            name: "RMCore",
            dependencies: [
                "RMShared",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ],
            path: "RMCore/Classes",
            exclude: [
                "RMCore-Prefix.pch",
                "Supporting Files",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include/Romo"),
                .headerSearchPath("Actuation"),
                .headerSearchPath("Actuation/Driving"),
                .headerSearchPath("Actuation/Driving/DriveController"),
                .headerSearchPath("Actuation/Head Tilt"),
                .headerSearchPath("Communication"),
                .headerSearchPath("Communication/FirmwareCommon"),
                .headerSearchPath("Communication/FirmwareUpdate"),
                .headerSearchPath("LEDs"),
                .headerSearchPath("Robot"),
                .headerSearchPath("Robot/Functionality"),
                .headerSearchPath("Sensing/Bump"),
                .headerSearchPath("Sensing/Inertial"),
                .headerSearchPath("Sensing/Stasis"),
                .headerSearchPath("Utilities/DSP"),
                .headerSearchPath("Utilities/IMU"),
            ],
            linkerSettings: [
                .linkedFramework("ExternalAccessory"),
            ]
        ),
        .target(
            name: "RMCharacter",
            dependencies: [
                "RMShared",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ],
            path: "RMCharacter",
            exclude: [
                "Examples",
                "_Pods.xcproject",
                "Classes/RMCharacter-Prefix.pch",
            ],
            sources: ["Classes"],
            resources: [
                .process("Assets/Media.xcassets"),
            ],
            publicHeadersPath: "Classes/include",
            cSettings: [
                .headerSearchPath("Classes/include/Romo"),
                .headerSearchPath("Classes/Categories"),
                .headerSearchPath("Classes/Face"),
                .headerSearchPath("Classes/Nervous System"),
                .headerSearchPath("Classes/Utilities"),
                .headerSearchPath("Classes/Voice"),
            ]
        ),
    ]
)
