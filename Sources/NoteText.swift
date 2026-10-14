import AppKit
import Foundation

enum NoteText {
    static let untitled = "New Note"
    static let noAdditionalText = "No additional text"

    /// The first non-empty line is the title; the next non-empty line is the preview.
    static func summary(of text: String) -> (title: String, preview: String) {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first else { return (untitled, noAdditionalText) }
        let title = stripListMarker(first)
        let preview = lines.dropFirst().first.map(stripListMarker) ?? noAdditionalText
        return (title.isEmpty ? untitled : title, preview)
    }

    private static func stripListMarker(_ line: String) -> String {
        guard let marker = ListMarker.parse(line) else { return line }
        let index = String.Index(utf16Offset: marker.length, in: line)
        return String(line[index...]).trimmingCharacters(in: .whitespaces)
    }

    /// RTF is stored without foreground colors so text follows the current light/dark appearance.
    static func archive(_ text: NSAttributedString) -> Data {
        let copy = NSMutableAttributedString(attributedString: text)
        copy.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: copy.length))
        let range = NSRange(location: 0, length: copy.length)
        return (try? copy.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])) ?? Data()
    }

    static func load(_ data: Data) -> NSAttributedString {
        guard !data.isEmpty,
              let text = try? NSMutableAttributedString(
                  data: data,
                  options: [.documentType: NSAttributedString.DocumentType.rtf],
                  documentAttributes: nil)
        else { return NSAttributedString() }
        text.addAttribute(.foregroundColor, value: NSColor.textColor, range: NSRange(location: 0, length: text.length))
        return text
    }
}

enum ListKind: Equatable, CaseIterable {
    case bulleted, dashed, numbered

    func marker(number: Int) -> String {
        switch self {
        case .bulleted: "• "
        case .dashed: "– "
        case .numbered: "\(number). "
        }
    }
}

enum ListMarker {
    struct Match: Equatable {
        let kind: ListKind
        /// Marker length in UTF-16 code units, for use with `NSRange`.
        let length: Int
        let number: Int
    }

    static func parse(_ line: String) -> Match? {
        if line.hasPrefix("• ") { return Match(kind: .bulleted, length: 2, number: 1) }
        if line.hasPrefix("– ") { return Match(kind: .dashed, length: 2, number: 1) }
        let digits = line.prefix(while: \.isASCII).prefix(while: \.isNumber)
        guard !digits.isEmpty, let number = Int(digits),
              line.dropFirst(digits.count).hasPrefix(". ")
        else { return nil }
        return Match(kind: .numbered, length: digits.utf16.count + 2, number: number)
    }
}

enum RecentlyDeleted {
    static let retentionDays = 30

    static func isExpired(deletedAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        guard let expiry = calendar.date(byAdding: .day, value: retentionDays, to: deletedAt) else { return false }
        return now >= expiry
    }
}
