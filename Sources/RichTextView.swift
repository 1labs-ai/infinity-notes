import AppKit
import SwiftUI

/// Gives SwiftUI controls outside the editor access to its text view, e.g. to apply a suggested title.
@MainActor
final class EditorHandle {
    weak var textView: NSTextView?
}

struct RichTextView: NSViewRepresentable {
    let note: Note
    var handle: EditorHandle?

    func makeCoordinator() -> Coordinator { Coordinator(note: note) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NoteTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 24, height: 20)
        textView.drawsBackground = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = note.deletedAt == nil
        textView.delegate = context.coordinator

        textView.textStorage?.setAttributedString(NoteText.load(note.rtfData))
        // New notes start with a Title line, as in Apple Notes.
        textView.typingAttributes = ParagraphStyleKind.defaultAttributes(note.isEmpty ? .title : .body)
        scrollView.documentView = textView
        handle?.textView = textView

        if note.isEmpty, textView.isEditable {
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {}

    final class Coordinator: NSObject, NSTextViewDelegate {
        let note: Note

        init(note: Note) { self.note = note }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            note.update(from: textView.attributedString())
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            let text = textView.string as NSString
            let selection = textView.selectedRange()
            let paragraph = text.paragraphRange(for: NSRange(location: selection.location, length: 0))
            let line = text.substring(with: paragraph).trimmingCharacters(in: .newlines)

            // Return continues a list; Return on an empty item ends it.
            if let marker = ListMarker.parse(line) {
                if (line as NSString).length == marker.length {
                    textView.insertText("", replacementRange: NSRange(location: paragraph.location, length: marker.length))
                } else {
                    textView.insertText("\n" + marker.kind.marker(number: marker.number + 1), replacementRange: selection)
                }
                return true
            }

            // The title line hands over to Body on Return.
            if let font = textView.typingAttributes[.font] as? NSFont, font.pointSize == ParagraphStyleKind.title.font.pointSize {
                textView.insertText("\n", replacementRange: selection)
                textView.typingAttributes = ParagraphStyleKind.defaultAttributes(.body)
                return true
            }
            return false
        }
    }
}
