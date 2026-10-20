import Foundation

public enum ShortcutNames {
    /// A name that's safe as a file name: no "/" or ":", no surrounding spaces, and no leading
    /// "." (which would hide the app). Empty if nothing usable is left.
    public static func fileName(for name: String) -> String {
        var cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        return cleaned
    }

    /// The name a new shortcut gets: the app's name without ".app".
    public static func defaultName(forAppAt path: String) -> String {
        let last = (path as NSString).lastPathComponent
        return last.hasSuffix(".app") ? String(last.dropLast(4)) : last
    }

    /// The bundle ID Automator gives apps it saves: "com.apple.automator." plus the name,
    /// with anything other than letters, digits, "." and "-" replaced by "-".
    public static func bundleIdentifier(for name: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        let suffix = String(fileName(for: name).map { allowed.contains($0) ? $0 : "-" })
        return "com.apple.automator." + (suffix.isEmpty ? "shortcut" : suffix)
    }
}
