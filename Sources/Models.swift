import AppKit
import Foundation
import SwiftData

@Model
final class Folder {
    var name: String
    var createdAt: Date
    var isDefault: Bool
    @Relationship(deleteRule: .nullify, inverse: \Note.folder)
    var notes: [Note] = []

    init(name: String, isDefault: Bool = false, createdAt: Date = .now) {
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

@Model
final class Note {
    var title: String
    var preview: String
    var plainText: String
    var rtfData: Data
    var createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool
    /// Set while the note is in Recently Deleted; `folder` is kept so the note can be recovered.
    var deletedAt: Date?
    var folder: Folder?

    init(folder: Folder?, now: Date = .now) {
        let summary = NoteText.summary(of: "")
        self.title = summary.title
        self.preview = summary.preview
        self.plainText = ""
        self.rtfData = Data()
        self.createdAt = now
        self.modifiedAt = now
        self.isPinned = false
        self.folder = folder
    }

    var isEmpty: Bool {
        plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func update(from text: NSAttributedString, now: Date = .now) {
        rtfData = NoteText.archive(text)
        plainText = text.string
        let summary = NoteText.summary(of: text.string)
        title = summary.title
        preview = summary.preview
        modifiedAt = now
    }
}
