import AppKit
import SwiftData
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

    // MARK: - Folder tree

    private final class Node: Equatable {
        var parent: Node?
        var children: [Node] = []

        init(_ parent: Node? = nil) {
            self.parent = parent
            parent?.children.append(self)
        }

        static func == (a: Node, b: Node) -> Bool { a === b }
    }

    private func canMove(_ node: Node, to parent: Node?) -> Bool {
        FolderTree.canMove(node, to: parent, parent: \.parent, children: \.children)
    }

    func testFolderDepthAndHeight() {
        let root = Node(), child = Node(root), grandchild = Node(child)
        XCTAssertEqual(FolderTree.depth(of: root, parent: \.parent), 1)
        XCTAssertEqual(FolderTree.depth(of: grandchild, parent: \.parent), 3)
        XCTAssertEqual(FolderTree.height(of: root, children: \.children), 3)
        XCTAssertEqual(FolderTree.height(of: grandchild, children: \.children), 1)
    }

    func testSubfolderDepthLimit() {
        var node = Node()
        for _ in 1..<FolderTree.maxDepth { node = Node(node) }
        XCTAssertEqual(FolderTree.depth(of: node, parent: \.parent), FolderTree.maxDepth)
        XCTAssertFalse(FolderTree.canAddSubfolder(to: node, parent: \.parent))
        XCTAssertTrue(FolderTree.canAddSubfolder(to: node.parent!, parent: \.parent))
    }

    func testFolderMoveRejectsCyclesAndNoOps() {
        let root = Node(), child = Node(root), grandchild = Node(child), other = Node()
        XCTAssertFalse(canMove(root, to: root), "into itself")
        XCTAssertFalse(canMove(root, to: grandchild), "into its own descendant")
        XCTAssertFalse(canMove(child, to: root), "already there")
        XCTAssertFalse(canMove(root, to: nil), "already top level")
        XCTAssertTrue(canMove(child, to: other))
        XCTAssertTrue(canMove(grandchild, to: nil))
    }

    func testFolderMoveRespectsDepthLimit() {
        // A 2-level subtree fits under a depth-2 folder (2 + 2 = 4) but not under a depth-3 one.
        let deep = Node(Node(Node()))
        let subtree = Node()
        _ = Node(subtree)
        XCTAssertTrue(canMove(subtree, to: deep.parent))
        XCTAssertFalse(canMove(subtree, to: deep))
    }

    func testFolderSubtreeAndFlatten() {
        let a = Node(), a1 = Node(a), a1x = Node(a1), a2 = Node(a), b = Node()
        XCTAssertEqual(FolderTree.subtree(of: a, children: \.children), [a, a1, a1x, a2])
        let rows = FolderTree.flatten([a, b], children: \.children)
        XCTAssertEqual(rows.map(\.node), [a, a1, a1x, a2, b])
        XCTAssertEqual(rows.map(\.level), [0, 1, 2, 1, 0])
    }

    @MainActor
    func testSubfolderRelationshipAndDragPayload() throws {
        let container = try ModelContainer(
            for: Folder.self, Note.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let parent = Folder(name: "Work")
        let child = Folder(name: "Projects", parent: parent)
        let note = Note(folder: child)
        context.insert(parent)
        context.insert(child)
        context.insert(note)
        try context.save()

        XCTAssertEqual(parent.children, [child])
        child.parent = nil
        try context.save()
        XCTAssertTrue(parent.children.isEmpty)

        XCTAssertEqual(DragPayload(DragPayload.note(note.persistentModelID).string), .note(note.persistentModelID))
        XCTAssertEqual(DragPayload(DragPayload.folder(child.persistentModelID).string), .folder(child.persistentModelID))
        XCTAssertNil(DragPayload("plain dragged text"))
    }
}
