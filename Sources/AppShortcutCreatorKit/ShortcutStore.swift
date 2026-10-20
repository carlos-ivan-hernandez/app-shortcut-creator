import Foundation

/// Where the list is saved. Everything lives in ~/Library/Application Support/AppShortcutCreator:
///
///     shortcuts.json   the destination folder and every shortcut's settings
///     icons/           a copy of each custom icon, so the shortcut can be recreated
///                      even after the original image is moved or deleted
public struct ShortcutStore {
    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public static var standard: ShortcutStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ShortcutStore(folder: support.appendingPathComponent("AppShortcutCreator", isDirectory: true))
    }

    public var libraryFile: URL { folder.appendingPathComponent("shortcuts.json") }
    public var iconsFolder: URL { folder.appendingPathComponent("icons", isDirectory: true) }

    public func iconURL(_ fileName: String) -> URL {
        iconsFolder.appendingPathComponent(fileName)
    }

    // MARK: - The list

    /// An empty library if nothing has been saved yet.
    public func load() throws -> ShortcutLibrary {
        guard FileManager.default.fileExists(atPath: libraryFile.path) else { return ShortcutLibrary() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ShortcutLibrary.self, from: Data(contentsOf: libraryFile))
    }

    public func save(_ library: ShortcutLibrary) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(library).write(to: libraryFile, options: .atomic)
    }

    // MARK: - Icons

    /// Saves `data` as a new icon for shortcut `id` and returns its file name.
    public func saveIcon(_ data: Data, for id: UUID, fileExtension: String) throws -> String {
        try FileManager.default.createDirectory(at: iconsFolder, withIntermediateDirectories: true)
        // A new name for every image, so a replaced icon is never confused with the old one.
        let token = UUID().uuidString.prefix(8).lowercased()
        let ext = fileExtension.isEmpty ? "" : "." + fileExtension.lowercased()
        let fileName = "\(id.uuidString.lowercased())-\(token)\(ext)"
        try data.write(to: iconURL(fileName), options: .atomic)
        return fileName
    }

    public func deleteIcon(_ fileName: String) {
        try? FileManager.default.removeItem(at: iconURL(fileName))
    }
}
