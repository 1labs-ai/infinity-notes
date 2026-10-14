import AppKit

/// The note editor's text view; distinct from field editors such as the search field.
final class NoteTextView: NSTextView {}

enum ParagraphStyleKind: CaseIterable {
    case title, heading, subheading, body, monospaced

    var name: String {
        switch self {
        case .title: "Title"
        case .heading: "Heading"
        case .subheading: "Subheading"
        case .body: "Body"
        case .monospaced: "Monostyled"
        }
    }

    var font: NSFont {
        switch self {
        case .title: .systemFont(ofSize: 24, weight: .bold)
        case .heading: .systemFont(ofSize: 18, weight: .bold)
        case .subheading: .systemFont(ofSize: 15, weight: .semibold)
        case .body: .systemFont(ofSize: 13)
        case .monospaced: .monospacedSystemFont(ofSize: 13, weight: .regular)
        }
    }

    static func defaultAttributes(_ kind: ParagraphStyleKind) -> [NSAttributedString.Key: Any] {
        [.font: kind.font, .foregroundColor: NSColor.textColor]
    }
}

@MainActor
enum TextFormatter {
    static var activeTextView: NoteTextView? {
        NSApp.keyWindow?.firstResponder as? NoteTextView
    }

    static func apply(_ kind: ParagraphStyleKind) {
        guard let textView = activeTextView, let storage = textView.textStorage else { return }
        let range = (textView.string as NSString).paragraphRange(for: textView.selectedRange())
        textView.typingAttributes[.font] = kind.font
        guard range.length > 0, textView.shouldChangeText(in: range, replacementString: nil) else { return }
        let manager = NSFontManager.shared
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            var font = kind.font
            if let old = value as? NSFont {
                let traits = manager.traits(of: old)
                if traits.contains(.italicFontMask) { font = manager.convert(font, toHaveTrait: .italicFontMask) }
                if traits.contains(.boldFontMask), kind == .body || kind == .monospaced {
                    font = manager.convert(font, toHaveTrait: .boldFontMask)
                }
            }
            storage.addAttribute(.font, value: font, range: subrange)
        }
        storage.endEditing()
        textView.didChangeText()
    }

    static func toggle(_ trait: NSFontTraitMask) {
        guard let textView = activeTextView, let storage = textView.textStorage else { return }
        let manager = NSFontManager.shared
        let fallback = ParagraphStyleKind.body.font
        let selection = textView.selectedRange()
        guard selection.length > 0 else {
            let font = textView.typingAttributes[.font] as? NSFont ?? fallback
            textView.typingAttributes[.font] = manager.traits(of: font).contains(trait)
                ? manager.convert(font, toNotHaveTrait: trait)
                : manager.convert(font, toHaveTrait: trait)
            return
        }
        var allHave = true
        storage.enumerateAttribute(.font, in: selection) { value, _, stop in
            if !manager.traits(of: value as? NSFont ?? fallback).contains(trait) {
                allHave = false
                stop.pointee = true
            }
        }
        guard textView.shouldChangeText(in: selection, replacementString: nil) else { return }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: selection) { value, subrange, _ in
            let font = value as? NSFont ?? fallback
            let converted = allHave ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait)
            storage.addAttribute(.font, value: converted, range: subrange)
        }
        storage.endEditing()
        textView.didChangeText()
    }

    /// Toggles underline or strikethrough.
    static func toggle(_ key: NSAttributedString.Key) {
        guard let textView = activeTextView, let storage = textView.textStorage else { return }
        let on = NSUnderlineStyle.single.rawValue
        let selection = textView.selectedRange()
        guard selection.length > 0 else {
            let current = textView.typingAttributes[key] as? Int ?? 0
            textView.typingAttributes[key] = current == 0 ? on : nil
            return
        }
        var allHave = true
        storage.enumerateAttribute(key, in: selection) { value, _, stop in
            if (value as? Int ?? 0) == 0 {
                allHave = false
                stop.pointee = true
            }
        }
        guard textView.shouldChangeText(in: selection, replacementString: nil) else { return }
        storage.beginEditing()
        if allHave {
            storage.removeAttribute(key, range: selection)
        } else {
            storage.addAttribute(key, value: on, range: selection)
        }
        storage.endEditing()
        textView.didChangeText()
    }

    /// Adds `kind` markers to the selected paragraphs, or removes them if every paragraph already has them.
    static func toggleList(_ kind: ListKind) {
        guard let textView = activeTextView, let storage = textView.textStorage else { return }
        let text = textView.string as NSString
        let range = text.paragraphRange(for: textView.selectedRange())
        var lines: [NSRange] = []
        text.enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, line, _, _ in
            lines.append(line)
        }
        if lines.isEmpty { lines = [NSRange(location: range.location, length: 0)] }
        let removing = lines.allSatisfy { ListMarker.parse(text.substring(with: $0))?.kind == kind }
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        for (index, line) in lines.enumerated().reversed() {
            let existing = ListMarker.parse(text.substring(with: line))?.length ?? 0
            let marker = removing ? "" : kind.marker(number: index + 1)
            let attributes = line.length > 0 ? storage.attributes(at: line.location, effectiveRange: nil) : textView.typingAttributes
            storage.replaceCharacters(
                in: NSRange(location: line.location, length: existing),
                with: NSAttributedString(string: marker, attributes: attributes))
        }
        storage.endEditing()
        textView.didChangeText()
    }
}
