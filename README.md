# Notes Clone

A native macOS (SwiftUI + SwiftData) notes app modeled on Apple Notes' core features:
folders, a date-grouped notes list with pinning, a rich-text editor, search, and
Recently Deleted with 30-day retention.

The app is an original implementation. Its feature map came from static analysis
of the Notes app bundle with [REA](https://github.com/morluto/rea) — see
[docs/notes-feature-map.md](docs/notes-feature-map.md), where each item is marked
observed, inferred, or unknown. No Apple code or assets are included.

## Requirements

- macOS 15+, Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build and run

The Xcode project is generated from `project.yml` and is not committed.

```bash
xcodegen generate
open NotesClone.xcodeproj        # then Run (⌘R)
```

From the command line:

```bash
xcodebuild -project NotesClone.xcodeproj -scheme NotesClone -derivedDataPath build test
open build/Build/Products/Debug/NotesClone.app
```

## Layout

| Path | Contents |
|---|---|
| `Sources/Models.swift` | SwiftData `Folder` and `Note` models |
| `Sources/NoteText.swift` | Title/preview derivation, RTF storage, list markers, retention |
| `Sources/DateGrouping.swift` | Today / Yesterday / Previous 7 / 30 Days / month / year sections |
| `Sources/TextFormatting.swift` | Paragraph styles, bold/italic/underline/strikethrough, lists |
| `Sources/RichTextView.swift` | `NSTextView` editor bridge |
| `Sources/ContentView.swift`, `SidebarView.swift`, `NoteListView.swift` | Three-column UI |
| `Sources/NotesCloneApp.swift` | App entry, menu commands and shortcuts |
| `Tests/` | Unit tests for the pure logic |
| `scripts/make-icon.sh` | Regenerates the app icon from `scripts/make-icon.swift` |

## Not yet built

Gallery view, sort options, checklists, tables, attachments, subfolders, tags, sync.
