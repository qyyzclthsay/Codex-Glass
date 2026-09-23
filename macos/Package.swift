// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexGlass",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexGlass", targets: ["CodexGlass"])],
    targets: [
        .target(name: "CodexGlassCore"),
        .executableTarget(name: "CodexGlass", dependencies: ["CodexGlassCore"],
                          resources: [.process("Resources")]),
        .testTarget(name: "CodexGlassCoreTests", dependencies: ["CodexGlassCore"])
    ]
)
