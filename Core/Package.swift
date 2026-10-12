// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HerdCore", platforms: [.macOS(.v14)], products: [.library(name: "HerdCore", targets: ["HerdCore"]), .library(name: "PTY", targets: ["PTY"])], dependencies: [.package(url: "https://github.com/LebJe/TOMLKit", exact: "0.6.0")], targets: [.target(name: "HerdCore", dependencies: ["PTY", "TOMLKit"]), .target(name: "PTY", publicHeadersPath: "include"), .testTarget(name: "HerdCoreTests", dependencies: ["HerdCore"])])
