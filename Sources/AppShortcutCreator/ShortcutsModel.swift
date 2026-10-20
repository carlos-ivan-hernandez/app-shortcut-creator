import AppKit
import AppShortcutCreatorKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ShortcutsModel: ObservableObject {
    /// What happened the last time a shortcut was created in this session.
    enum RowStatus: Equatable {
        case creating
        case created(URL)
        case failed(String)
    }

    let store = ShortcutStore.standard
    @Published private(set) var library = ShortcutLibrary()
    /// Set if shortcuts.json couldn't be read. Nothing is saved while this is set, so a damaged
    /// file is never overwritten.
    @Published private(set) var loadError: String?
    @Published private(set) var rowStatus: [UUID: RowStatus] = [:]
    @Published private(set) var summary: String?
    @Published private(set) var isBusy = false
    /// Bumped when an icon changes, so rows redraw it.
    @Published private(set) var iconRevision = 0

    init() {
        do {
            library = try store.load()
        } catch {
            loadError = "\(store.libraryFile.path) couldn’t be read: \(error.localizedDescription)"
        }
    }

    var shortcuts: [ShortcutRecord] { library.shortcuts }

    var destinationFolder: URL? {
        library.destinationFolder.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Lowercased file names used by more than one shortcut. Those would overwrite each other.
    var duplicateNames: Set<String> {
        var seen: Set<String> = [], duplicates: Set<String> = []
        for shortcut in shortcuts {
            let key = ShortcutNames.fileName(for: shortcut.name).lowercased()
            if !seen.insert(key).inserted { duplicates.insert(key) }
        }
        return duplicates
    }

    func isDuplicate(_ shortcut: ShortcutRecord) -> Bool {
        duplicateNames.contains(ShortcutNames.fileName(for: shortcut.name).lowercased())
    }

    // MARK: - Editing the list

    /// Adds a shortcut for each app that isn't in the list yet. Anything that isn't an app is ignored.
    func addApps(_ urls: [URL]) {
        let existing = Set(shortcuts.map(\.appPath))
        let apps = urls.filter { $0.pathExtension.lowercased() == "app" && !existing.contains($0.path) }
        guard !apps.isEmpty else { return }
        for url in apps {
            library.shortcuts.append(ShortcutRecord(
                name: ShortcutNames.defaultName(forAppAt: url.path),
                appPath: url.path,
                bundleIdentifier: Bundle(url: url)?.bundleIdentifier
            ))
        }
        save()
    }

    func rename(_ id: UUID, to name: String) {
        update(id) { $0.name = name }
    }

    func changeApp(_ id: UUID, to url: URL) {
        update(id) {
            $0.appPath = url.path
            $0.bundleIdentifier = Bundle(url: url)?.bundleIdentifier
        }
    }

    /// Uses the image in `url` as the shortcut's icon. A file that isn't an image (an app, a
    /// folder, a document) gives its Finder icon instead.
    func setIcon(_ id: UUID, from url: URL) {
        let data: Data?
        let ext: String
        if NSImage(contentsOf: url) != nil, let original = try? Data(contentsOf: url) {
            data = original
            ext = url.pathExtension
        } else {
            data = IconMaker.pngData(NSWorkspace.shared.icon(forFile: url.path), pixels: 1024)
            ext = "png"
        }
        guard let data else {
            summary = "\(url.lastPathComponent) couldn’t be used as an icon."
            return
        }
        do {
            let fileName = try store.saveIcon(data, for: id, fileExtension: ext)
            let old = shortcuts.first { $0.id == id }?.iconFile
            update(id) { $0.iconFile = fileName }
            if let old { store.deleteIcon(old) }
            iconRevision += 1
        } catch {
            summary = "The icon couldn’t be saved: \(error.localizedDescription)"
        }
    }

    func useAppIcon(_ id: UUID) {
        guard let old = shortcuts.first(where: { $0.id == id })?.iconFile else { return }
        update(id) { $0.iconFile = nil }
        store.deleteIcon(old)
        iconRevision += 1
    }

    /// Removes shortcuts from the list. Shortcuts already created stay where they are.
    func remove(_ ids: Set<UUID>) {
        for shortcut in shortcuts where ids.contains(shortcut.id) {
            if let icon = shortcut.iconFile { store.deleteIcon(icon) }
            rowStatus[shortcut.id] = nil
        }
        library.shortcuts.removeAll { ids.contains($0.id) }
        save()
    }

    func setDestination(_ url: URL) {
        library.destinationFolder = url.path
        save()
    }

    func icon(for shortcut: ShortcutRecord) -> NSImage {
        if let file = shortcut.iconFile, let image = NSImage(contentsOf: store.iconURL(file)) {
            return image
        }
        return NSWorkspace.shared.icon(forFile: shortcut.appPath)
    }

    func createdURL(for shortcut: ShortcutRecord) -> URL? {
        guard let folder = destinationFolder else { return nil }
        let url = ShortcutBuilder.destination(for: shortcut, in: folder)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func update(_ id: UUID, _ change: (inout ShortcutRecord) -> Void) {
        guard let index = library.shortcuts.firstIndex(where: { $0.id == id }) else { return }
        change(&library.shortcuts[index])
        save()
    }

    private func save() {
        guard loadError == nil else { return }
        do {
            try store.save(library)
        } catch {
            summary = "The list couldn’t be saved: \(error.localizedDescription)"
        }
    }

    // MARK: - Creating shortcuts

    /// Creates (or recreates) the given shortcuts, in list order, in the destination folder.
    func create(_ ids: Set<UUID>) async {
        guard !isBusy, let folder = destinationFolder else { return }
        let targets = shortcuts.filter { ids.contains($0.id) }
        guard !targets.isEmpty else { return }

        isBusy = true
        summary = nil
        var created = 0, failed = 0
        for shortcut in targets {
            rowStatus[shortcut.id] = .creating
            let image = icon(for: shortcut)
            let result = await Task.detached(priority: .userInitiated) {
                Result(catching: { try ShortcutBuilder.build(shortcut, icon: image, in: folder) })
            }.value
            switch result {
            case let .success(url):
                rowStatus[shortcut.id] = .created(url)
                update(shortcut.id) { $0.lastCreated = Date() }
                created += 1
            case let .failure(error):
                rowStatus[shortcut.id] = .failed(error.localizedDescription)
                failed += 1
            }
        }
        isBusy = false

        let noun = created == 1 ? "shortcut" : "shortcuts"
        summary = failed == 0 ? "Created \(created) \(noun)." : "Created \(created) \(noun), \(failed) failed."
    }

    // MARK: - Panels

    func chooseApps() -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Choose Apps"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        return panel.runModal() == .OK ? panel.urls : []
    }

    func chooseIconFile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose an Icon"
        panel.message = "Choose an image (PNG, JPEG, ICNS…) or an app to use its icon."
        panel.prompt = "Use as Icon"
        panel.allowedContentTypes = [.image, .application]
        return panel.runModal() == .OK ? panel.url : nil
    }

    @discardableResult
    func chooseDestination() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Choose Where to Create Shortcuts"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = destinationFolder
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        setDestination(url)
        return true
    }
}
