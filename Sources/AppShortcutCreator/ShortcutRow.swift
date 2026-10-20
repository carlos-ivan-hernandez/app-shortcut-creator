import AppKit
import AppShortcutCreatorKit
import SwiftUI

struct ShortcutRow: View {
    @ObservedObject var model: ShortcutsModel
    let shortcut: ShortcutRecord
    let create: () -> Void
    @State private var isIconDropTargeted = false

    var body: some View {
        HStack(spacing: 12) {
            iconWell
            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: Binding(
                    get: { shortcut.name },
                    set: { model.rename(shortcut.id, to: $0) }
                ))
                .textFieldStyle(.plain)
                .font(.headline)
                Text(shortcut.appPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(shortcut.appPath)
                warnings
            }
            Spacer(minLength: 12)
            status
            Button("Create", action: create)
                .disabled(model.isBusy)
            menu
        }
        .padding(.vertical, 4)
        .contextMenu { menuItems }
    }

    private var iconWell: some View {
        Button {
            if let url = model.chooseIconFile() { model.setIcon(shortcut.id, from: url) }
        } label: {
            Image(nsImage: model.icon(for: shortcut))
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
                .id(model.iconRevision)
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isIconDropTargeted ? Color.accentColor : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .help(shortcut.iconFile == nil
            ? "Using the app’s icon. Click or drop an image here to use a custom icon."
            : "Custom icon. Click or drop an image here to change it.")
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.setIcon(shortcut.id, from: url)
            return true
        } isTargeted: { isIconDropTargeted = $0 }
    }

    @ViewBuilder
    private var warnings: some View {
        if ShortcutNames.fileName(for: shortcut.name).isEmpty {
            Label("Needs a name", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if model.isDuplicate(shortcut) {
            Label("Another shortcut has this name; they’d replace each other", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        if !FileManager.default.fileExists(atPath: shortcut.appPath) {
            Label("App not found", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        if case let .failed(message) = model.rowStatus[shortcut.id] {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.rowStatus[shortcut.id] {
        case .creating:
            ProgressView().controlSize(.small)
        case .created:
            Label("Created", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case let .failed(message):
            Label("Failed", systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .help(message)
        case nil:
            if let date = shortcut.lastCreated {
                Text("Created \(date.formatted(.relative(presentation: .named)))")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .help(date.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private var menu: some View {
        Menu { menuItems } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
    }

    @ViewBuilder
    private var menuItems: some View {
        Button("Choose Icon…") {
            if let url = model.chooseIconFile() { model.setIcon(shortcut.id, from: url) }
        }
        Button("Use the App’s Icon") { model.useAppIcon(shortcut.id) }
            .disabled(shortcut.iconFile == nil)
        Button("Change App…") {
            if let url = model.chooseApps().first { model.changeApp(shortcut.id, to: url) }
        }
        Divider()
        Button("Show Shortcut in Finder") {
            if let url = model.createdURL(for: shortcut) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        .disabled(model.createdURL(for: shortcut) == nil)
        Button("Show App in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: shortcut.appPath)])
        }
        if case let .failed(message) = model.rowStatus[shortcut.id] {
            Button("Copy Error") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
        }
        Divider()
        Button("Remove from List") { model.remove([shortcut.id]) }
    }
}
