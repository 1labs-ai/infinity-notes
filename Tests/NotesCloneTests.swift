import AppKit
import XCTest
@testable import NotesClone

final class NotesCloneTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testSummaryUsesFirstTwoNonEmptyLines() {
        let s = NoteText.summary(of: "\n  Groceries  \n\n• Milk\nEggs")
        XCTAssertEqual(s.title, "Groceries")
        XCTAssertEqual(s.preview, "Milk")
    }

    func testSummaryOfEmptyNote() {
        let s = NoteText.summary(of: " \n ")
        XCTAssertEqual(s.title, "New Note")
        XCTAssertEqual(s.preview, "No additional text")
    }

    func testListMarkerParsing() {
        XCTAssertEqual(ListMarker.parse("• item"), .init(kind: .bulleted, length: 2, number: 1))
        XCTAssertEqual(ListMarker.parse("– item"), .init(kind: .dashed, length: 2, number: 1))
        XCTAssertEqual(ListMarker.parse("12. item"), .init(kind: .numbered, length: 4, number: 12))
        XCTAssertNil(ListMarker.parse("12 item"))
        XCTAssertNil(ListMarker.parse("plain"))
    }

    func testDateSections() {
        let now = date(2026, 10, 14)
        XCTAssertEqual(DateSection.section(for: date(2026, 10, 14, 1), now: now, calendar: calendar), .today)
        XCTAssertEqual(DateSection.section(for: date(2026, 10, 13), now: now, calendar: calendar), .yesterday)
        XCTAssertEqual(DateSection.section(for: date(2026, 10, 7), now: now, calendar: calendar), .previous7Days)
        XCTAssertEqual(DateSection.section(for: date(2026, 9, 20), now: now, calendar: calendar), .previous30Days)
        XCTAssertEqual(DateSection.section(for: date(2026, 3, 2), now: now, calendar: calendar), .month(3))
        XCTAssertEqual(DateSection.section(for: date(2024, 12, 31), now: now, calendar: calendar), .year(2024))
    }

    func testGroupingKeepsOrder() {
        let now = date(2026, 10, 14)
        let dates = [date(2026, 10, 14), date(2026, 10, 14, 2), date(2026, 10, 13), date(2025, 1, 1)]
        let groups = DateSection.group(dates, date: { $0 }, now: now, calendar: calendar)
        XCTAssertEqual(groups.map(\.0), [.today, .yesterday, .year(2025)])
        XCTAssertEqual(groups[0].1.count, 2)
    }

    func testRecentlyDeletedRetention() {
        let deleted = date(2026, 9, 1)
        XCTAssertFalse(RecentlyDeleted.isExpired(deletedAt: deleted, now: date(2026, 9, 30), calendar: calendar))
        XCTAssertTrue(RecentlyDeleted.isExpired(deletedAt: deleted, now: date(2026, 10, 1), calendar: calendar))
    }

    func testRTFRoundTripKeepsFormattingAndDropsColor() {
        let bold = NSFontManager.shared.convert(ParagraphStyleKind.body.font, toHaveTrait: .boldFontMask)
        let text = NSAttributedString(string: "Hello", attributes: [.font: bold, .foregroundColor: NSColor.red])
        let loaded = NoteText.load(NoteText.archive(text))
        XCTAssertEqual(loaded.string, "Hello")
        let font = loaded.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertTrue(NSFontManager.shared.traits(of: font!).contains(.boldFontMask))
        XCTAssertEqual(loaded.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, NSColor.textColor)
    }
}
