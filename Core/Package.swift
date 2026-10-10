// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HerdCore", platforms: [.macOS(.v14)], products: [.library(name: "HerdCore", targets: ["HerdCore"]), .library(name: "PTY", targets: ["PTY"])], targets: [.target(name: "HerdCore"), .target(name: "PTY", publicHeadersPath: "include"), .testTarget(name: "HerdCoreTests", dependencies: ["HerdCore"])])
