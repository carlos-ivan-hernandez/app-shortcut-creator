import Foundation

/// The shell command a shortcut's "Run Shell Script" action runs.
public enum LauncherScript {
    /// Opens the app at `appPath`. If it's no longer there (moved or renamed) and the app has
    /// a bundle ID, opens whichever copy macOS knows by that ID instead.
    public static func command(appPath: String, bundleIdentifier: String?) -> String {
        let open = "open \(shellQuoted(appPath))"
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return open }
        return "\(open) 2>/dev/null || open -b \(shellQuoted(bundleIdentifier))"
    }

    /// Single-quotes `text` for sh/zsh, so spaces, quotes and `$` are taken literally.
    public static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
