import AppShortcutCreatorKit
import XCTest

final class LauncherScriptTests: XCTestCase {
    func testQuotesSpacesAndApostrophes() {
        XCTAssertEqual(LauncherScript.shellQuoted("/Applications/My App.app"), "'/Applications/My App.app'")
        XCTAssertEqual(LauncherScript.shellQuoted("Bob's $HOME"), #"'Bob'\''s $HOME'"#)
    }

    func testFallsBackToBundleIdentifier() {
        XCTAssertEqual(
            LauncherScript.command(appPath: "/Applications/Safari.app", bundleIdentifier: "com.apple.Safari"),
            "open '/Applications/Safari.app' 2>/dev/null || open -b 'com.apple.Safari'"
        )
    }

    func testPathOnlyWithoutBundleIdentifier() {
        XCTAssertEqual(LauncherScript.command(appPath: "/Applications/X.app", bundleIdentifier: nil), "open '/Applications/X.app'")
        XCTAssertEqual(LauncherScript.command(appPath: "/Applications/X.app", bundleIdentifier: ""), "open '/Applications/X.app'")
    }
}

final class ShortcutNamesTests: XCTestCase {
    func testFileName() {
        XCTAssertEqual(ShortcutNames.fileName(for: "  Mail / Work: Inbox  "), "Mail - Work- Inbox")
        XCTAssertEqual(ShortcutNames.fileName(for: "..hidden"), "hidden")
        XCTAssertEqual(ShortcutNames.fileName(for: "   "), "")
    }

    func testDefaultName() {
        XCTAssertEqual(ShortcutNames.defaultName(forAppAt: "/Applications/Visual Studio Code.app"), "Visual Studio Code")
    }

    func testBundleIdentifier() {
        XCTAssertEqual(ShortcutNames.bundleIdentifier(for: "My Café App"), "com.apple.automator.My-Caf--App")
        XCTAssertEqual(ShortcutNames.bundleIdentifier(for: ""), "com.apple.automator.shortcut")
    }
}

final class WorkflowDocumentTests: XCTestCase {
    func testRoundTripsCommand() throws {
        let command = LauncherScript.command(appPath: "/Applications/Bob's App.app", bundleIdentifier: "com.example.bob")
        let data = try WorkflowDocument.data(command: command)
        XCTAssertEqual(WorkflowDocument.command(in: data), command)
    }

    func testIsAnApplicationWorkflowWithOneShellScriptAction() throws {
        let data = try WorkflowDocument.data(command: "open -a Safari")
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let metadata = try XCTUnwrap(plist["workflowMetaData"] as? [String: Any])
        XCTAssertEqual(metadata["workflowTypeIdentifier"] as? String, "com.apple.Automator.application")

        let actions = try XCTUnwrap(plist["actions"] as? [[String: Any]])
        XCTAssertEqual(actions.count, 1)
        let action = try XCTUnwrap(actions[0]["action"] as? [String: Any])
        XCTAssertEqual(action["BundleIdentifier"] as? String, "com.apple.RunShellScript")
        let parameters = try XCTUnwrap(action["ActionParameters"] as? [String: Any])
        XCTAssertEqual(parameters["shell"] as? String, "/bin/zsh")
        XCTAssertEqual((action["arguments"] as? [String: Any])?.count, 5)
    }
}

final class ShortcutStoreTests: XCTestCase {
    private var store: ShortcutStore!

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ShortcutStoreTests-\(UUID().uuidString)")
        store = ShortcutStore(folder: folder)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: store.folder)
    }

    func testEmptyWhenNothingSaved() throws {
        XCTAssertEqual(try store.load(), ShortcutLibrary())
    }

    func testSaveAndLoad() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let library = ShortcutLibrary(destinationFolder: "/Users/me/Shortcuts", shortcuts: [
            ShortcutRecord(name: "Safari", appPath: "/Applications/Safari.app", bundleIdentifier: "com.apple.Safari", lastCreated: date),
            ShortcutRecord(name: "Notes", appPath: "/System/Applications/Notes.app", iconFile: "abc.png"),
        ])
        try store.save(library)
        XCTAssertEqual(try store.load(), library)
    }

    func testLoadsRecordsWithoutOptionalFields() throws {
        try FileManager.default.createDirectory(at: store.folder, withIntermediateDirectories: true)
        let json = #"{"shortcuts":[{"id":"6E1A6A43-5D3C-4F55-9F44-6E36A4E0F9B1","name":"X","appPath":"/Applications/X.app"}]}"#
        try Data(json.utf8).write(to: store.libraryFile)
        let library = try store.load()
        XCTAssertNil(library.destinationFolder)
        XCTAssertEqual(library.shortcuts.first?.name, "X")
        XCTAssertNil(library.shortcuts.first?.iconFile)
    }

    func testSaveAndDeleteIcon() throws {
        let id = UUID()
        let name = try store.saveIcon(Data([1, 2, 3]), for: id, fileExtension: "PNG")
        XCTAssertTrue(name.hasPrefix(id.uuidString.lowercased()))
        XCTAssertTrue(name.hasSuffix(".png"))
        XCTAssertEqual(try Data(contentsOf: store.iconURL(name)), Data([1, 2, 3]))
        store.deleteIcon(name)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.iconURL(name).path))
    }
}
