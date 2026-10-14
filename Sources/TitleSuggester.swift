import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Suggests a title from a note's content. Uses the on-device Apple Intelligence model when it is
/// available and falls back to keyword extraction otherwise, so suggestions work offline on every Mac.
enum TitleSuggester {
    static let maxWords = 5

    /// The note's current title is a poor one: missing, a list item, or a whole sentence.
    static func titleNeedsImprovement(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first, lines.count > 1 || first.count > 60 else { return false }
        return ListMarker.parse(first) != nil || first.count > 60
    }

    static func suggestions(for text: String) async -> [String] {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return [] }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), let generated = await generatedTitles(for: body), !generated.isEmpty {
            return generated
        }
        #endif
        return keywordTitle(for: body).map { [$0] } ?? []
    }

    // MARK: - Keyword extraction

    /// The most frequent nouns and names, in the order they first appear, title-cased.
    static func keywordTitle(for text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        var counts: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]
        var display: [String: String] = [:]
        var position = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, range in
            defer { position += 1 }
            guard tag == .noun || tag == .adjective else { return true }
            let word = String(text[range])
            guard word.count > 2, word.rangeOfCharacter(from: .letters) != nil else { return true }
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue ?? word
            let key = lemma.lowercased()
            // Nouns carry the topic; adjectives only count half so they rarely lead.
            counts[key, default: 0] += tag == .noun ? 2 : 1
            if firstSeen[key] == nil {
                firstSeen[key] = position
                display[key] = word
            }
            return true
        }
        let ranked = counts.keys
            .sorted { (counts[$0]!, -firstSeen[$0]!) > (counts[$1]!, -firstSeen[$1]!) }
            .prefix(3)
            .sorted { firstSeen[$0]! < firstSeen[$1]! }
        guard !ranked.isEmpty else { return fallbackTitle(for: text) }
        return ranked.map { titleCase(display[$0]!) }.joined(separator: " ")
    }

    /// For text with no nouns (e.g. numbers only), the start of the first line.
    private static func fallbackTitle(for text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace).prefix(maxWords)
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    private static func titleCase(_ word: String) -> String {
        // Keep acronyms and mixed case such as "iPhone" as written.
        guard word == word.lowercased() else { return word }
        return word.prefix(1).uppercased() + word.dropFirst()
    }

    /// Strips quotes, trailing punctuation and list numbering a model may add.
    static func clean(_ title: String) -> String {
        var line = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let marker = ListMarker.parse(line) {
            line = String(line.dropFirst(marker.length))
        }
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’*-•# ").union(.whitespaces))
        while let last = line.last, ".:;!".contains(last) { line.removeLast() }
        return line
    }

    // MARK: - On-device model

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func generatedTitles(for text: String) async -> [String]? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: """
            You write short titles for personal notes. Reply with exactly three alternative titles, \
            one per line, each at most \(maxWords) words, with no numbering, quotes or explanation.
            """)
        let prompt = "Note:\n\(text.prefix(4000))"
        guard let response = try? await session.respond(to: prompt) else { return nil }
        var seen = Set<String>()
        return response.content
            .split(whereSeparator: \.isNewline)
            .map { clean(String($0)) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(3)
            .map { $0 }
    }
    #endif
}
