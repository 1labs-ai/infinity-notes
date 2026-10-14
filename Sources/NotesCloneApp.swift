import SwiftData
import SwiftUI

@main
struct NotesCloneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, minHeight: 420)
        }
        .modelContainer(for: [Folder.self, Note.self])
        .commands { NotesCommands() }
    }
}

struct NotesActions {
    var newNote: () -> Void
    var newFolder: () -> Void
    var togglePin: (() -> Void)?
    var deleteNote: (() -> Void)?
    var isPinned: Bool
}

extension FocusedValues {
    @Entry var notesActions: NotesActions?
}

struct NotesCommands: Commands {
    @FocusedValue(\.notesActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") { actions?.newNote() }
                .keyboardShortcut("n")
                .disabled(actions == nil)
            Button("New Folder") { actions?.newFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Divider()
            Button(actions?.isPinned == true ? "Unpin Note" : "Pin Note") { actions?.togglePin?() }
                .disabled(actions?.togglePin == nil)
            Button("Delete Note") { actions?.deleteNote?() }
                .disabled(actions?.deleteNote == nil)
        }

        CommandMenu("Format") {
            ForEach(ParagraphStyleKind.allCases, id: \.self) { kind in
                Button(kind.name) { TextFormatter.apply(kind) }
                    .keyboardShortcut(kind.shortcut, modifiers: [.command, .shift])
            }
            Divider()
            Button("Bulleted List") { TextFormatter.toggleList(.bulleted) }
                .keyboardShortcut("7", modifiers: [.command, .shift])
            Button("Dashed List") { TextFormatter.toggleList(.dashed) }
                .keyboardShortcut("8", modifiers: [.command, .shift])
            Button("Numbered List") { TextFormatter.toggleList(.numbered) }
                .keyboardShortcut("9", modifiers: [.command, .shift])
            Divider()
            Button("Bold") { TextFormatter.toggle(.boldFontMask) }
                .keyboardShortcut("b")
            Button("Italic") { TextFormatter.toggle(.italicFontMask) }
                .keyboardShortcut("i")
            Button("Underline") { TextFormatter.toggle(.underlineStyle) }
                .keyboardShortcut("u")
            Button("Strikethrough") { TextFormatter.toggle(.strikethroughStyle) }
        }
    }
}

extension ParagraphStyleKind {
    var shortcut: KeyEquivalent {
        switch self {
        case .title: "t"
        case .heading: "h"
        case .subheading: "j"
        case .body: "b"
        case .monospaced: "m"
        }
    }
}
