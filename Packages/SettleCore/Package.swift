// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SettleCore",
    platforms: [.macOS("26.0")],
    products: [.library(name: "SettleCore", targets: ["SettleCore"])],
    targets: [
        .target(name: "SettleCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "SettleCoreTests", dependencies: ["SettleCore"]),
    ]
)
