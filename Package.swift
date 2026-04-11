// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SeqTraceMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SeqTraceMac", targets: ["SeqTraceMac"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SeqTraceMac",
            resources: [
                .copy("Resources/USER_GUIDE.md"),
            ]
        ),
        .testTarget(
            name: "SeqTraceMacTests",
            dependencies: ["SeqTraceMac"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
