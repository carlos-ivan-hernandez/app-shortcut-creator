// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppShortcutCreator",
    platforms: [.macOS(.v13)],
    targets: [
        // Foundation-only logic: the saved list, the workflow file, names and the launch command.
        .target(name: "AppShortcutCreatorKit"),
        // The SwiftUI app.
        .executableTarget(name: "AppShortcutCreator", dependencies: ["AppShortcutCreatorKit"]),
        .testTarget(name: "AppShortcutCreatorKitTests", dependencies: ["AppShortcutCreatorKit"]),
    ]
)
