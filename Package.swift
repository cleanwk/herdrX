// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HerdrX", platforms: [.macOS(.v14)], dependencies: [
    .package(path: "Core"),
    .package(url: "https://github.com/Lakr233/libghostty-spm", exact: "1.6.20260909"),
    .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")
], targets: [.executableTarget(name: "HerdrX", dependencies: [.product(name: "HerdCore", package: "Core"), .product(name: "PTY", package: "Core"), .product(name: "GhosttyTerminal", package: "libghostty-spm"), .product(name: "Sparkle", package: "Sparkle")], path: "App", exclude: ["Info.plist", "AppIcon.icon"], swiftSettings: [.swiftLanguageMode(.v5)])])
