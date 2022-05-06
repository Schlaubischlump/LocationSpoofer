// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocationSpoofer",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "LocationSpoofer",
            targets: ["CMobileDevice", "SimulatorDevice", "LocationSpoofer"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/Schlaubischlump/CLogger.git",
            from: "0.0.1"
        ),
        // OpenSSL is required by libimobiledevice
        .package(
            url: "https://github.com/passepartoutvpn/openssl-apple.git",
            from: "1.0.0"
        ),
    ],
    targets: [
        .binaryTarget(
                    name: "plist",
                    url: "https://github.com/Schlaubischlump/XCF/releases/download/v0.0.1/plist.xcframework.zip",
                    checksum: "44e29d0d469eb7f1762714798a1f1635db92f467f557c9ee8953c3dbb1733d01"
        ),
        .binaryTarget(
                    name: "usbmuxd",
                    url: "https://github.com/Schlaubischlump/XCF/releases/download/v0.0.1/usbmuxd.xcframework.zip",
                    checksum: "6f63532feea9ddb16288bfdd99a4514730a40b62689e94d3bb99d2e0529ea176"

        ),
        .binaryTarget(
                    name: "imobiledevice",
                    url: "https://github.com/Schlaubischlump/XCF/releases/download/v0.0.1/imobiledevice.xcframework.zip",
                    checksum: "ab5284a8cd479d0d5399a1de63111683356ccc1dbac2952e75509e18dbbd927f"
        ),
        .target(
            name: "CMobileDevice",
            dependencies: ["CLogger", "openssl-apple", "plist", "usbmuxd", "imobiledevice"],
            path: "Sources/CMobileDevice"
        ),
        .target(
            name: "SimulatorDevice",
            dependencies: ["CLogger"],
            path: "Sources/SimulatorDevice"
        ),
        .target(
            name: "LocationSpoofer",
            dependencies: ["CMobileDevice", "SimulatorDevice"],
            path: "Sources/LocationSpoofer"
        )
    ]
)
