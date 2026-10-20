import Foundation

/// One shortcut in the list: an Automator app named `name` that opens the app at `appPath`.
public struct ShortcutRecord: Codable, Identifiable, Equatable {
    public var id: UUID
    /// The shortcut's name in Finder, without ".app".
    public var name: String
    /// The app the shortcut opens.
    public var appPath: String
    /// The target app's bundle ID, used if the app is no longer at `appPath`.
    public var bundleIdentifier: String?
    /// The custom icon's file name in the store's icons folder. Nil uses the target app's icon.
    public var iconFile: String?
    /// When the shortcut was last created.
    public var lastCreated: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        appPath: String,
        bundleIdentifier: String? = nil,
        iconFile: String? = nil,
        lastCreated: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.appPath = appPath
        self.bundleIdentifier = bundleIdentifier
        self.iconFile = iconFile
        self.lastCreated = lastCreated
    }
}

/// Everything the app remembers between launches.
public struct ShortcutLibrary: Codable, Equatable {
    /// The folder shortcuts are created in.
    public var destinationFolder: String?
    public var shortcuts: [ShortcutRecord]

    public init(destinationFolder: String? = nil, shortcuts: [ShortcutRecord] = []) {
        self.destinationFolder = destinationFolder
        self.shortcuts = shortcuts
    }
}
