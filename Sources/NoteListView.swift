import SwiftData
import SwiftUI

struct NoteListView: View {
    let sections: [NoteSection]
    @Binding var selection: PersistentIdentifier?
    let isRecentlyDeleted: Bool
    let showsFolder: Bool
    let emptyMessage: String
    let onTogglePin: (Note) -> Void
    let onDelete: (Note) -> Void
    let onRecover: (Note) -> Void

    var body: some View {
        List(selection: $selection) {
            if isRecentlyDeleted, !sections.isEmpty {
                Text("You can recover or remove from Recently Deleted within \(RecentlyDeleted.retentionDays) days.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .selectionDisabled()
            }
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.notes) { note in
                        NoteRow(note: note, showsFolder: showsFolder)
                            .tag(note.persistentModelID)
                            .contextMenu { menu(for: note) }
                    }
                }
            }
        }
        .overlay {
            if sections.isEmpty {
                Text(emptyMessage).foregroundStyle(.secondary)
            }
        }
        .onDeleteCommand {
            guard let note = sections.lazy.flatMap(\.notes).first(where: { $0.persistentModelID == selection }) else { return }
            onDelete(note)
        }
    }

    @ViewBuilder
    private func menu(for note: Note) -> some View {
        if note.deletedAt != nil {
            Button("Recover") { onRecover(note) }
            Button("Delete", role: .destructive) { onDelete(note) }
        } else {
            Button(note.isPinned ? "Unpin Note" : "Pin Note") { onTogglePin(note) }
            Divider()
            Button("Delete", role: .destructive) { onDelete(note) }
        }
    }
}

private struct NoteRow: View {
    let note: Note
    let showsFolder: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if note.isPinned {
                    Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
                }
                Text(note.title).fontWeight(.semibold).lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(DateSection.rowLabel(for: note.modifiedAt, now: .now))
                Text(note.preview).foregroundStyle(.secondary).lineLimit(1)
            }
            .font(.callout)
            if showsFolder, let folder = note.folder {
                Label(folder.name, systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
