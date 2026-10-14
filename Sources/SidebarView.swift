import SwiftData
import SwiftUI

/// A folder with its nesting level, for "Move to" menus.
struct FolderOption: Identifiable {
    let folder: Folder
    let level: Int

    var id: PersistentIdentifier { folder.persistentModelID }
    /// Em spaces, because menus trim ordinary leading spaces.
    var indentedName: String { String(repeating: "\u{2003}", count: level) + folder.name }
}

struct SidebarView: View {
    /// Top-level folders; subfolders are reached through `Folder.sortedChildren`.
    let folders: [Folder]
    let folderOptions: [FolderOption]
    let deletedCount: Int
    @Binding var selection: SidebarItem?
    @Binding var renamingFolder: PersistentIdentifier?
    let noteCount: (Folder) -> Int
    let canAddSubfolder: (Folder) -> Bool
    let canMoveFolder: (Folder, Folder?) -> Bool
    let onNewFolder: () -> Void
    let onNewSubfolder: (Folder) -> Void
    let onMoveFolder: (Folder, Folder?) -> Void
    let onDeleteFolder: (Folder) -> Void
    /// Dropped payload strings and the target folder (`nil` = top level); returns whether anything moved.
    let onDrop: ([String], Folder?) -> Bool

    @State private var folderToDelete: Folder?
    @State private var expanded: Set<PersistentIdentifier> = []
    @State private var isAccountTargeted = false

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(visibleRows) { row in
                    folderRow(row)
                }
                if deletedCount > 0 || selection == .recentlyDeleted {
                    HStack {
                        Label("Recently Deleted", systemImage: "trash")
                        Spacer()
                        Text("\(deletedCount)").foregroundStyle(.secondary)
                    }
                    .tag(SidebarItem.recentlyDeleted)
                }
            } header: {
                // Dropping a folder on the account header moves it to the top level.
                Text("On My Mac")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isAccountTargeted ? Color.accentColor.opacity(0.2) : .clear)
                    .dropDestination(for: String.self) { items, _ in
                        onDrop(items, nil)
                    } isTargeted: { isAccountTargeted = $0 }
            }
        }
        // One list-level menu for the right-clicked row, rather than a `.contextMenu` per row.
        .contextMenu(forSelectionType: SidebarItem.self) { items in
            if items.count == 1, case .folder(let id)? = items.first,
               let folder = folderOptions.first(where: { $0.id == id })?.folder {
                menu(for: folder)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: onNewFolder) { Label("New Folder", systemImage: "plus.circle") }
                    .buttonStyle(.borderless)
                Spacer()
            }
            .padding(10)
        }
        .onChange(of: selection) { _, selection in revealSelection(selection) }
        .confirmationDialog(
            "Delete Folder?",
            isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } }),
            presenting: folderToDelete
        ) { folder in
            Button("Delete Folder", role: .destructive) { onDeleteFolder(folder) }
        } message: { folder in
            Text("All notes and any subfolders will be deleted.")
        }
    }

    /// The folder tree flattened to rows, skipping subfolders of collapsed folders. Rows are flat
    /// (not nested DisclosureGroups) so expansion is driven only by `expanded`.
    private var visibleRows: [FolderOption] {
        FolderTree.visibleRows(folders, children: \.sortedChildren, isExpanded: { expanded.contains($0.persistentModelID) })
            .map { FolderOption(folder: $0.node, level: $0.level) }
    }

    private func folderRow(_ row: FolderOption) -> some View {
        let folder = row.folder
        return FolderRow(
            folder: folder,
            level: row.level,
            hasChildren: !folder.children.isEmpty,
            isExpanded: expanded.contains(folder.persistentModelID),
            onToggle: { toggleExpanded(folder) },
            count: noteCount(folder),
            isRenaming: Binding(
                get: { renamingFolder == folder.persistentModelID },
                set: { if !$0 { renamingFolder = nil } }),
            onDrop: { items in
                let moved = onDrop(items, folder)
                if moved { expanded.insert(folder.persistentModelID) }
                return moved
            })
            .tag(SidebarItem.folder(folder.persistentModelID))
    }

    @ViewBuilder
    private func menu(for folder: Folder) -> some View {
        Button("New Subfolder") {
            expanded.insert(folder.persistentModelID)
            onNewSubfolder(folder)
        }
        .disabled(!canAddSubfolder(folder))
        if !folder.isDefault {
            Button("Rename Folder") { renamingFolder = folder.persistentModelID }
            Menu("Move to") {
                Button("On My Mac") { onMoveFolder(folder, nil) }
                    .disabled(!canMoveFolder(folder, nil))
                Divider()
                ForEach(folderOptions) { option in
                    Button(option.indentedName) {
                        expanded.insert(option.id)
                        onMoveFolder(folder, option.folder)
                    }
                    .disabled(!canMoveFolder(folder, option.folder))
                }
            }
            Divider()
            Button("Delete Folder") { folderToDelete = folder }
        }
    }

    private func toggleExpanded(_ folder: Folder) {
        let id = folder.persistentModelID
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    /// Expands the ancestors of a newly selected folder, such as a just-created subfolder, so its row is visible.
    private func revealSelection(_ selection: SidebarItem?) {
        guard case .folder(let id) = selection,
              let folder = folderOptions.first(where: { $0.id == id })?.folder
        else { return }
        var ancestor = folder.parent
        while let next = ancestor {
            expanded.insert(next.persistentModelID)
            ancestor = next.parent
        }
    }
}

private struct FolderRow: View {
    @Bindable var folder: Folder
    let level: Int
    let hasChildren: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let count: Int
    @Binding var isRenaming: Bool
    let onDrop: ([String]) -> Bool
    @FocusState private var focused: Bool
    @State private var isTargeted = false

    var body: some View {
        if folder.isDefault || isRenaming {
            content
        } else {
            content.draggable(DragPayload.folder(folder.persistentModelID).string)
        }
    }

    private var content: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: CGFloat(level) * 14, height: 1)
            Button(action: onToggle) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hasChildren ? 1 : 0)
            .disabled(!hasChildren)
            .help(isExpanded ? "Collapse" : "Expand")
            if isRenaming {
                Label {
                    TextField("Folder Name", text: $folder.name)
                        .focused($focused)
                        .onSubmit { finishRenaming() }
                        .onAppear { focused = true }
                        .onChange(of: focused) { _, isFocused in if !isFocused { finishRenaming() } }
                } icon: {
                    Image(systemName: "folder")
                }
            } else {
                Label(folder.name, systemImage: "folder")
            }
            Spacer()
            Text("\(count)").foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isTargeted ? Color.accentColor.opacity(0.25) : .clear)
                .padding(-2))
        .dropDestination(for: String.self) { items, _ in
            onDrop(items)
        } isTargeted: { isTargeted = $0 }
    }

    private func finishRenaming() {
        if folder.name.trimmingCharacters(in: .whitespaces).isEmpty { folder.name = "New Folder" }
        isRenaming = false
    }
}
