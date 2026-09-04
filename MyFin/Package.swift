// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyFin",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", from: "4.10.0")
    ],
    targets: [
        .executableTarget(
            name: "MyFin",
            dependencies: [
                .product(name: "SQLCipher", package: "SQLCipher.swift")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-DSQLITE_HAS_CODEC=1"])
            ]
        ),
        .testTarget(
            name: "MyFinTests",
            dependencies: ["MyFin"],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-DSQLITE_HAS_CODEC=1"])
            ]
        )
    ]
)
