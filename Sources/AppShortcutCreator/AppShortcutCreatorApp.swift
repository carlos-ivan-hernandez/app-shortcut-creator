import AppKit
import SwiftUI

@main
@MainActor
enum Entry {
    static func main() {
        // `AppShortcutCreator icon <image> <output.icns>` draws this app's own icon. build.sh uses it.
        let arguments = CommandLine.arguments
        if arguments.count == 4, arguments[1] == "icon" {
            do {
                guard let image = NSImage(contentsOfFile: arguments[2]) else { throw BuildError.iconFailed }
                try IconMaker.writeICNS(IconMaker.gridIcon(from: image), to: URL(fileURLWithPath: arguments[3]))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        AppShortcutCreatorApp.main()
    }
}

struct AppShortcutCreatorApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var model = ShortcutsModel()

    var body: some Scene {
        Window("AppShortcutCreator", id: "main") {
            ContentView(model: model)
        }
        .defaultSize(width: 760, height: 520)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run from `swift run` (no app bundle), the app would otherwise start in the background.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
