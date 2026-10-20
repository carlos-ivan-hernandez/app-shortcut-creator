import AppKit
import AppShortcutCreatorKit
import CoreServices

enum BuildError: LocalizedError {
    case stubMissing
    case noName
    case appMissing(String)
    case iconFailed
    case commandFailed(String, output: String)

    var errorDescription: String? {
        switch self {
        case .stubMissing:
            "Automator isn’t available on this Mac (\(ShortcutBuilder.stubApp.path) is missing)."
        case .noName:
            "The shortcut needs a name."
        case let .appMissing(path):
            "The app isn’t at \(path) any more. Use Change App… to pick it again."
        case .iconFailed:
            "The icon couldn’t be drawn."
        case let .commandFailed(command, output):
            "\((command as NSString).lastPathComponent) failed: \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}

/// Makes an Automator app the same way Automator does when you save a workflow as an
/// Application: a copy of macOS's Automator Application Stub with the workflow, a name and an
/// icon added, then signed again.
enum ShortcutBuilder {
    static let stubApp = URL(fileURLWithPath: "/System/Library/CoreServices/Automator Application Stub.app")
    /// The icon name Automator apps use. Keeping it means Automator treats the icon as its own.
    private static let iconName = "ApplicationStub"

    static func destination(for shortcut: ShortcutRecord, in folder: URL) -> URL {
        folder.appendingPathComponent(ShortcutNames.fileName(for: shortcut.name) + ".app")
    }

    /// Creates the shortcut in `folder`, replacing (moving to the Trash) one already there.
    @discardableResult
    static func build(_ shortcut: ShortcutRecord, icon: NSImage, in folder: URL) throws -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: stubApp.path) else { throw BuildError.stubMissing }
        guard !ShortcutNames.fileName(for: shortcut.name).isEmpty else { throw BuildError.noName }
        if !fileManager.fileExists(atPath: shortcut.appPath) && targetURLByBundleID(shortcut) == nil {
            throw BuildError.appMissing(shortcut.appPath)
        }

        let destination = Self.destination(for: shortcut, in: folder)
        let staging = fileManager.temporaryDirectory.appendingPathComponent("AppShortcutCreator-\(UUID().uuidString)")
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        let app = staging.appendingPathComponent(destination.lastPathComponent)
        try fileManager.copyItem(at: stubApp, to: app)
        // Files copied from /System can come out read-only.
        try Shell.run("/bin/chmod", ["-R", "u+w", app.path])

        let contents = app.appendingPathComponent("Contents")
        let resources = contents.appendingPathComponent("Resources")
        try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)

        let infoURL = contents.appendingPathComponent("Info.plist")
        var info = (try? PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil)) as? [String: Any] ?? [:]
        info["CFBundleName"] = shortcut.name
        info["CFBundleDisplayName"] = shortcut.name
        info["CFBundleIdentifier"] = ShortcutNames.bundleIdentifier(for: shortcut.name)
        info["CFBundleIconFile"] = iconName
        // An asset-catalog icon name would win over the .icns, so the custom icon wouldn't show.
        info.removeValue(forKey: "CFBundleIconName")
        info["AMIsApplet"] = true
        info["AMStayOpen"] = false
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)

        let command = LauncherScript.command(appPath: shortcut.appPath, bundleIdentifier: shortcut.bundleIdentifier)
        let workflowURL = contents.appendingPathComponent("document.wflow")
        try WorkflowDocument.data(command: command).write(to: workflowURL)

        try IconMaker.writeICNS(icon, to: resources.appendingPathComponent(iconName + ".icns"))

        // The stub's signature doesn't cover the files just added, so replace it with an ad-hoc
        // one, as Automator does. Extended attributes make codesign refuse.
        try Shell.run("/usr/bin/xattr", ["-cr", app.path])
        // codesign treats a loose file directly in Contents as nested code that must already be
        // signed, so sign the workflow on its own first (its signature goes in its extended
        // attributes), then the app.
        try Shell.run("/usr/bin/codesign", ["--force", "--sign", "-", workflowURL.path])
        try Shell.run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])

        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.trashItem(at: destination, resultingItemURL: nil)
        }
        try fileManager.moveItem(at: app, to: destination)

        // Tell Launch Services about the new bundle so Finder and the Dock show the new icon.
        _ = LSRegisterURL(destination as CFURL, true)
        NSWorkspace.shared.noteFileSystemChanged(destination.path)
        return destination
    }

    private static func targetURLByBundleID(_ shortcut: ShortcutRecord) -> URL? {
        guard let id = shortcut.bundleIdentifier else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
    }
}

enum Shell {
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BuildError.commandFailed(executable, output: output)
        }
        return output
    }
}
