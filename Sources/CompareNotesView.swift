import AppKit
import SwiftData
import SwiftUI

enum NoteDiff {
    /// Indices of the paragraphs that exist only on the left (removed) and only on the right (added),
    /// ignoring surrounding whitespace.
    static func changedLines(left: String, right: String) -> (removed: IndexSet, added: IndexSet) {
        let a = paragraphs(left).map { $0.trimmingCharacters(in: .whitespaces) }
        let b = paragraphs(right).map { $0.trimmingCharacters(in: .whitespaces) }
        var removed = IndexSet()
        var added = IndexSet()
        for change in b.difference(from: a) {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): added.insert(offset)
            }
        }
        return (removed, added)
    }

    /// Paragraphs as NSString sees them, so indices line up with the attributed text.
    static func paragraphs(_ text: String) -> [String] {
        var result: [String] = []
        let string = text as NSString
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: .byParagraphs) { line, _, _, _ in
            result.append(line ?? "")
        }
        return result
    }

    /// The note's formatted text with the given paragraphs highlighted.
    static func highlighted(_ text: NSAttributedString, lines: IndexSet, color: NSColor) -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: text)
        guard !lines.isEmpty else { return copy }
        let string = copy.string as NSString
        var index = 0
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: [.byParagraphs, .substringNotRequired]) { _, line, _, _ in
            if lines.contains(index), line.length > 0 {
                copy.addAttribute(.backgroundColor, value: color, range: line)
            }
            index += 1
        }
        return copy
    }
}

/// Two notes side by side, read-only, with optional highlighting of the lines that differ.
struct CompareNotesView: View {
    let notes: [Note]
    @State var left: PersistentIdentifier?
    @State var right: PersistentIdentifier?
    @State private var highlightsDifferences = true
    @Environment(\.dismiss) private var dismiss

    private func lookup(_ id: PersistentIdentifier?) -> Note? {
        notes.first(where: { $0.persistentModelID == id })
    }

    private var diff: (removed: IndexSet, added: IndexSet) {
        guard highlightsDifferences, let l = lookup(left), let r = lookup(right) else { return ([], []) }
        return NoteDiff.changedLines(left: l.plainText, right: r.plainText)
    }

    var body: some View {
        let diff = diff
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                column(selection: $left, lines: diff.removed, color: .systemRed)
                Divider()
                column(selection: $right, lines: diff.added, color: .systemGreen)
            }
            Divider()
            HStack {
                Toggle("Highlight Differences", isOn: $highlightsDifferences)
                if highlightsDifferences, lookup(left) != nil, lookup(right) != nil {
                    Text(summary(diff)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    swap(&left, &right)
                } label: {
                    Label("Swap", systemImage: "arrow.left.arrow.right")
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 860, idealWidth: 1000, minHeight: 520, idealHeight: 640)
    }

    private func column(selection: Binding<PersistentIdentifier?>, lines: IndexSet, color: NSColor) -> some View {
        VStack(spacing: 0) {
            Picker("Note", selection: selection) {
                Text("Choose a Note").tag(PersistentIdentifier?.none)
                ForEach(notes) { note in
                    Text(note.title).tag(Optional(note.persistentModelID))
                }
            }
            .labelsHidden()
            .padding(10)
            Divider()
            if let note = lookup(selection.wrappedValue) {
                Text(note.modifiedAt.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                ReadOnlyTextView(text: NoteDiff.highlighted(
                    NoteText.load(note.rtfData), lines: lines, color: color.withAlphaComponent(0.22)))
            } else {
                Text("No Note Selected")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summary(_ diff: (removed: IndexSet, added: IndexSet)) -> String {
        if diff.removed.isEmpty, diff.added.isEmpty { return "The notes are identical." }
        return "\(diff.removed.count) line\(diff.removed.count == 1 ? "" : "s") only on the left, "
            + "\(diff.added.count) only on the right"
    }
}

private struct ReadOnlyTextView: NSViewRepresentable {
    let text: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 20, height: 16)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              textView.attributedString() != text
        else { return }
        textView.textStorage?.setAttributedString(text)
    }
}
