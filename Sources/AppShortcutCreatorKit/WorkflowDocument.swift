import Foundation

/// The document.wflow inside an Automator app: a workflow with a single "Run Shell Script"
/// action. This is the same file Automator writes when you save such a workflow as an
/// Application, so the shortcut can also be opened and edited in Automator.
public enum WorkflowDocument {
    public static let shell = "/bin/zsh"

    public static func data(command: String) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: propertyList(command: command), format: .xml, options: 0)
    }

    public static func propertyList(command: String) -> [String: Any] {
        [
            "AMApplicationBuild": "523",
            "AMApplicationVersion": "2.10",
            "AMDocumentVersion": "2",
            "actions": [["action": runShellScriptAction(command: command), "isViewVisible": 1]],
            "connectors": [String: Any](),
            "workflowMetaData": ["workflowTypeIdentifier": "com.apple.Automator.application"],
        ]
    }

    private static func runShellScriptAction(command: String) -> [String: Any] {
        let bundlePath = "/System/Library/Automator/Run Shell Script.action"
        let strings: [String: Any] = ["Container": "List", "Types": ["com.apple.cocoa.string"]]
        var accepts = strings
        accepts["Optional"] = true

        // Automator numbers the action's parameters; "default value" is what a new action starts with.
        let arguments: [(name: String, defaultValue: Any)] = [
            ("inputMethod", 0),
            ("CheckedForUserDefaultShell", false),
            ("source", ""),
            ("COMMAND_STRING", ""),
            ("shell", "/bin/sh"),
        ]
        var argumentList: [String: Any] = [:]
        for (index, argument) in arguments.enumerated() {
            argumentList[String(index)] = [
                "default value": argument.defaultValue,
                "name": argument.name,
                "required": "0",
                "type": "0",
                "uuid": String(index),
            ] as [String: Any]
        }

        return [
            "AMAccepts": accepts,
            "AMActionVersion": "2.0.3",
            "AMApplication": ["Automator"],
            "AMParameterProperties": Dictionary(uniqueKeysWithValues: arguments.map { ($0.name, [String: Any]()) }),
            "AMProvides": strings,
            "ActionBundlePath": bundlePath,
            "ActionName": "Run Shell Script",
            "ActionParameters": [
                "COMMAND_STRING": command,
                "CheckedForUserDefaultShell": true,
                // 0: input is passed on stdin. The shortcut gets no input, so it doesn't matter.
                "inputMethod": 0,
                "shell": shell,
                "source": "",
            ] as [String: Any],
            "BundleIdentifier": "com.apple.RunShellScript",
            "CFBundleVersion": "2.0.3",
            "CanShowSelectedItemsWhenRun": false,
            "CanShowWhenRun": true,
            "Category": ["AMCategoryUtilities"],
            "Class Name": "RunShellScriptAction",
            "InputUUID": UUID().uuidString,
            "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
            "OutputUUID": UUID().uuidString,
            "UUID": UUID().uuidString,
            "UnlocalizedApplications": ["Automator"],
            "arguments": argumentList,
            "isViewVisible": 1,
            "location": "309.000000:253.000000",
            "nibPath": bundlePath + "/Contents/Resources/Base.lproj/main.nib",
        ]
    }

    /// The command in a workflow made by `data(command:)`, or nil if it has no shell script action.
    public static func command(in data: Data) -> String? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let actions = plist["actions"] as? [[String: Any]]
        else { return nil }
        for entry in actions {
            if let action = entry["action"] as? [String: Any],
               let parameters = action["ActionParameters"] as? [String: Any],
               let command = parameters["COMMAND_STRING"] as? String {
                return command
            }
        }
        return nil
    }
}
