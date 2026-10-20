# AppShortcutCreator

A small macOS app that makes Automator shortcuts for your apps. Each shortcut is an
Automator application that opens an app. Pick the apps, pick a folder, and click
**Create All**. The app remembers the list, so you can recreate every shortcut at any time.

## Requirements

- macOS 13 Ventura or later
- To build: Xcode or the Xcode command line tools (`xcode-select --install`)

## Build

```bash
./scripts/build.sh            # creates "dist/AppShortcutCreator.app"
./scripts/build.sh --install  # also copies it into /Applications
swift run AppShortcutCreator  # run without making an app bundle
swift test                    # run the tests
```

## Using it

1. **Choose…** the folder to create shortcuts in.
2. Add apps: click **Add Apps…**, or drag apps from Finder onto the window.
3. Change any shortcut's name by clicking on it and typing.
4. To use a custom icon, click the icon or drop an image on it. PNG, JPEG, ICNS and other
   image files work. You can also choose an app, and its icon is used.
   **Use the App's Icon** in the ⋯ menu goes back to the target app's icon.
5. Click **Create All**, **Create Selected**, or **Create** on a single row.

Creating a shortcut again replaces the old one, which goes to the Trash. **Remove** takes a
shortcut off the list. Shortcuts you've already created aren't deleted.

## What gets saved

Everything is in `~/Library/Application Support/AppShortcutCreator`:

| File | Contents |
| --- | --- |
| `shortcuts.json` | The destination folder and each shortcut's name, target app and icon |
| `icons/` | A copy of each custom icon, so shortcuts can be recreated after the original image is moved or deleted |

## How shortcuts are made

Each shortcut is built the way Automator builds an app when you save a workflow as an
Application:

1. Copy macOS's `/System/Library/CoreServices/Automator Application Stub.app`.
2. Add a `document.wflow` with one **Run Shell Script** action:
   `open '/Applications/Some App.app' 2>/dev/null || open -b 'com.example.someapp'`.
   This opens the app at the path you picked. If the app isn't there any more, it opens the
   app with the same bundle ID.
3. Set the name and bundle ID (`com.apple.automator.<name>`, as Automator does), and write
   the icon to `Contents/Resources/ApplicationStub.icns`.
4. Sign it ad hoc with `codesign --sign -`.

You can open the shortcuts in Automator to inspect or edit them.

## App icon

AppShortcutCreator's own icon is [Support/AppIcon.png](Support/AppIcon.png). `build.sh` puts
it on the macOS icon grid (a rounded square with a shadow) by running
`AppShortcutCreator icon <image> <output.icns>`. To change the icon, replace the image with a
square one, at least 512 px and ideally 1024 px, with no rounded corners of its own.
