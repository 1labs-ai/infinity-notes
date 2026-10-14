import SwiftData
import SwiftUI

struct SidebarView: View {
    let folders: [Folder]
    let deletedCount: Int
    @Binding var selection: SidebarItem?
    @Binding var renamingFolder: PersistentIdentifier?
    let noteCount: (Folder) -> Int
    let onNewFolder: () -> Void
    let onDeleteFolder: (Folder) -> Void

    @State private var folderToDelete: Folder?

    var body: some View {
        List(selection: $selection) {
            Section("On My Mac") {
                ForEach(folders) { folder in
                    FolderRow(
                        folder: folder,
                        count: noteCount(folder),
                        isRenaming: Binding(
                            get: { renamingFolder == folder.persistentModelID },
                            set: { if !$0 { renamingFolder = nil } }))
                        .tag(SidebarItem.folder(folder.persistentModelID))
                        .contextMenu {
                            if !folder.isDefault {
                                Button("Rename Folder") { renamingFolder = folder.persistentModelID }
                                Button("Delete Folder") { folderToDelete = folder }
                            }
                        }
                }
                if deletedCount > 0 || selection == .recentlyDeleted {
                    HStack {
                        Label("Recently Deleted", systemImage: "trash")
                        Spacer()
                        Text("\(deletedCount)").foregroundStyle(.secondary)
                    }
                    .tag(SidebarItem.recentlyDeleted)
                }
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
}

private struct FolderRow: View {
    @Bindable var folder: Folder
    let count: Int
    @Binding var isRenaming: Bool
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
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
    }

    private func finishRenaming() {
        if folder.name.trimmingCharacters(in: .whitespaces).isEmpty { folder.name = "New Folder" }
        isRenaming = false
    }
}
