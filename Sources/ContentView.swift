import SwiftData
import SwiftUI

enum SidebarItem: Hashable {
    case folder(PersistentIdentifier)
    case recentlyDeleted
}

struct NoteSection: Identifiable {
    let id: String
    let title: String
    let notes: [Note]
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Folder.createdAt) private var allFolders: [Folder]
    @Query(sort: \Note.modifiedAt, order: .reverse) private var allNotes: [Note]

    @State private var sidebarSelection: SidebarItem?
    @State private var noteSelection: PersistentIdentifier?
    @State private var searchText = ""
    @State private var renamingFolder: PersistentIdentifier?
    @State private var noteToDeletePermanently: Note?

    private var folders: [Folder] {
        allFolders.sorted { $0.isDefault && !$1.isDefault }
    }

    private var defaultFolder: Folder? { folders.first(where: \.isDefault) ?? folders.first }

    private var selectedFolder: Folder? {
        guard case .folder(let id) = sidebarSelection else { return nil }
        return folders.first { $0.persistentModelID == id }
    }

    private var isShowingRecentlyDeleted: Bool { sidebarSelection == .recentlyDeleted }
    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var visibleNotes: [Note] {
        if isSearching {
            let query = searchText.trimmingCharacters(in: .whitespaces)
            return allNotes.filter {
                ($0.deletedAt != nil) == isShowingRecentlyDeleted && $0.plainText.localizedCaseInsensitiveContains(query)
            }
        }
        if isShowingRecentlyDeleted { return allNotes.filter { $0.deletedAt != nil } }
        guard let folder = selectedFolder else { return [] }
        return allNotes.filter { $0.deletedAt == nil && $0.folder == folder }
    }

    private var sections: [NoteSection] {
        let notes = visibleNotes
        var result: [NoteSection] = []
        let pinned = notes.filter(\.isPinned)
        if !pinned.isEmpty, !isShowingRecentlyDeleted {
            result.append(NoteSection(id: "pinned", title: "Pinned", notes: pinned))
        }
        let rest = isShowingRecentlyDeleted ? notes : notes.filter { !$0.isPinned }
        for (section, notes) in DateSection.group(rest, date: \.modifiedAt, now: .now) {
            result.append(NoteSection(id: "\(section)", title: section.title(), notes: notes))
        }
        return result
    }

    private var selectedNote: Note? {
        guard let noteSelection else { return nil }
        return allNotes.first { $0.persistentModelID == noteSelection }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                folders: folders,
                deletedCount: allNotes.filter { $0.deletedAt != nil }.count,
                selection: $sidebarSelection,
                renamingFolder: $renamingFolder,
                noteCount: { folder in folder.notes.filter { $0.deletedAt == nil }.count },
                onNewFolder: newFolder,
                onDeleteFolder: deleteFolder)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            NoteListView(
                sections: sections,
                selection: $noteSelection,
                isRecentlyDeleted: isShowingRecentlyDeleted,
                showsFolder: isSearching,
                emptyMessage: isSearching ? "No Results" : "No Notes",
                onTogglePin: togglePin,
                onDelete: delete,
                onRecover: recover)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
                .navigationTitle(isShowingRecentlyDeleted ? "Recently Deleted" : selectedFolder?.name ?? "Notes")
                .toolbar {
                    ToolbarItem {
                        Button(action: newNote) { Label("New Note", systemImage: "square.and.pencil") }
                            .help("Create a note")
                    }
                }
        } detail: {
            if let note = selectedNote {
                NoteEditorView(note: note, onDelete: { delete(note) })
            } else {
                Text("No Note Selected").foregroundStyle(.secondary)
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
        .focusedSceneValue(\.notesActions, actions)
        .confirmationDialog(
            "Are you sure you want to delete the note permanently?",
            isPresented: Binding(get: { noteToDeletePermanently != nil }, set: { if !$0 { noteToDeletePermanently = nil } }),
            presenting: noteToDeletePermanently
        ) { note in
            Button("Delete", role: .destructive) { deletePermanently(note) }
        } message: { _ in
            Text("This note will be deleted. This action cannot be undone.")
        }
        .onAppear(perform: bootstrap)
        .onChange(of: noteSelection) { old, _ in discardIfEmpty(old) }
        .onChange(of: sidebarSelection) { _, _ in noteSelection = sections.first?.notes.first?.persistentModelID }
    }

    private var actions: NotesActions {
        let note = selectedNote
        return NotesActions(
            newNote: newNote,
            newFolder: newFolder,
            togglePin: note.flatMap { note in note.deletedAt == nil ? { togglePin(note) } : nil },
            deleteNote: note.map { note in { delete(note) } },
            isPinned: note?.isPinned ?? false)
    }

    // MARK: - Actions

    private func bootstrap() {
        if allFolders.isEmpty {
            context.insert(Folder(name: "Notes", isDefault: true))
        }
        for note in allNotes {
            if let deletedAt = note.deletedAt, RecentlyDeleted.isExpired(deletedAt: deletedAt, now: .now) {
                context.delete(note)
            }
        }
        try? context.save()
        if sidebarSelection == nil, let folder = defaultFolder {
            sidebarSelection = .folder(folder.persistentModelID)
        }
    }

    private func newNote() {
        guard let folder = selectedFolder ?? defaultFolder else { return }
        if isShowingRecentlyDeleted { sidebarSelection = .folder(folder.persistentModelID) }
        searchText = ""
        let note = Note(folder: folder)
        context.insert(note)
        try? context.save()
        noteSelection = note.persistentModelID
    }

    private func newFolder() {
        let names = Set(allFolders.map(\.name))
        var name = "New Folder"
        var index = 2
        while names.contains(name) {
            name = "New Folder \(index)"
            index += 1
        }
        let folder = Folder(name: name)
        context.insert(folder)
        try? context.save()
        sidebarSelection = .folder(folder.persistentModelID)
        renamingFolder = folder.persistentModelID
    }

    private func deleteFolder(_ folder: Folder) {
        guard !folder.isDefault else { return }
        let now = Date.now
        for note in folder.notes where note.deletedAt == nil {
            note.deletedAt = now
            note.isPinned = false
        }
        if selectedFolder == folder, let fallback = defaultFolder {
            sidebarSelection = .folder(fallback.persistentModelID)
        }
        context.delete(folder)
        try? context.save()
    }

    private func togglePin(_ note: Note) {
        note.isPinned.toggle()
    }

    private func delete(_ note: Note) {
        if note.deletedAt != nil {
            noteToDeletePermanently = note
            return
        }
        if noteSelection == note.persistentModelID { noteSelection = nil }
        if note.isEmpty {
            context.delete(note)
        } else {
            note.deletedAt = .now
            note.isPinned = false
        }
        try? context.save()
    }

    private func deletePermanently(_ note: Note) {
        if noteSelection == note.persistentModelID { noteSelection = nil }
        context.delete(note)
        try? context.save()
    }

    private func recover(_ note: Note) {
        note.deletedAt = nil
        if note.folder == nil { note.folder = defaultFolder }
        try? context.save()
    }

    /// Apple Notes discards a new note that was left empty.
    private func discardIfEmpty(_ id: PersistentIdentifier?) {
        guard let id, let note = allNotes.first(where: { $0.persistentModelID == id }),
              note.isEmpty, note.deletedAt == nil
        else { return }
        context.delete(note)
        try? context.save()
    }
}

struct NoteEditorView: View {
    let note: Note
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if note.deletedAt != nil {
                Text("Can’t modify a note in Recently Deleted. To edit this note, you’ll need to recover it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            Text(note.modifiedAt.formatted(date: .long, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
            RichTextView(note: note)
                .id(note.persistentModelID)
        }
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    ForEach(ParagraphStyleKind.allCases, id: \.self) { kind in
                        Button(kind.name) { TextFormatter.apply(kind) }
                    }
                    Divider()
                    Button("Bulleted List") { TextFormatter.toggleList(.bulleted) }
                    Button("Dashed List") { TextFormatter.toggleList(.dashed) }
                    Button("Numbered List") { TextFormatter.toggleList(.numbered) }
                } label: {
                    Label("Format", systemImage: "textformat")
                }
                .help("Text formatting")
                .disabled(note.deletedAt != nil)

                Button(action: onDelete) { Label("Delete", systemImage: "trash") }
                    .help("Delete note")
            }
        }
    }
}
