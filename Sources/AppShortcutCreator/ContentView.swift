import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ShortcutsModel
    @State private var selection = Set<UUID>()
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.loadError {
                Label(error + " Changes won’t be saved until it’s fixed or removed.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                Divider()
            }
            destinationBar
            Divider()
            if model.shortcuts.isEmpty {
                emptyState
            } else {
                list
            }
            Divider()
            bottomBar
        }
        .frame(minWidth: 640, minHeight: 360)
        .dropDestination(for: URL.self) { urls, _ in
            model.addApps(urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
    }

    private var destinationBar: some View {
        HStack(spacing: 8) {
            Text("Create shortcuts in:")
                .foregroundStyle(.secondary)
            if let folder = model.destinationFolder {
                Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(folder.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(folder.path)
            } else {
                Text("No folder chosen")
                    .foregroundStyle(.secondary)
                    .italic()
            }
            Spacer()
            Button("Choose…") { model.chooseDestination() }
            if let folder = model.destinationFolder {
                Button("Open") { NSWorkspace.shared.open(folder) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Drag apps here, or click Add Apps…")
                .font(.title3)
            Text("Each app gets an Automator shortcut that opens it. The list is saved, so you can recreate them all at any time.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(model.shortcuts) { shortcut in
                ShortcutRow(model: model, shortcut: shortcut, create: { create([shortcut.id]) })
                    .tag(shortcut.id)
            }
        }
        .onDeleteCommand { removeSelected() }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button("Add Apps…") { model.addApps(model.chooseApps()) }
            Button("Remove") { removeSelected() }
                .disabled(selection.isEmpty)
                .help("Removes the selected shortcuts from the list. Shortcuts already created aren’t deleted.")
            Spacer()
            if model.isBusy {
                ProgressView().controlSize(.small)
            }
            if let summary = model.summary {
                Text(summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button("Create Selected") { create(selection) }
                .disabled(selection.isEmpty || model.isBusy)
            Button("Create All") { create(Set(model.shortcuts.map(\.id))) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.shortcuts.isEmpty || model.isBusy)
        }
        .padding(12)
    }

    private func removeSelected() {
        model.remove(selection)
        selection = []
    }

    private func create(_ ids: Set<UUID>) {
        if model.destinationFolder == nil && !model.chooseDestination() { return }
        Task { await model.create(ids) }
    }
}
