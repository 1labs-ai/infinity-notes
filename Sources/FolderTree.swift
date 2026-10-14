import Foundation
import SwiftData

/// Folder hierarchy rules. Written against `parent`/`children` closures so they can be tested without SwiftData.
enum FolderTree {
    /// Apple Notes caps nesting ("Notes is limited to %lu levels of folders."); the exact value is unknown.
    static let maxDepth = 4

    /// 1 for a top-level folder.
    static func depth<T>(of node: T, parent: (T) -> T?) -> Int {
        var depth = 1
        var current = parent(node)
        while let next = current {
            depth += 1
            current = parent(next)
        }
        return depth
    }

    /// Levels in the subtree rooted at `node`; 1 for a folder without subfolders.
    static func height<T>(of node: T, children: (T) -> [T]) -> Int {
        1 + (children(node).map { height(of: $0, children: children) }.max() ?? 0)
    }

    static func isAncestor<T: Equatable>(_ ancestor: T, of node: T, parent: (T) -> T?) -> Bool {
        var current = parent(node)
        while let next = current {
            if next == ancestor { return true }
            current = parent(next)
        }
        return false
    }

    static func canAddSubfolder<T>(to node: T, parent: (T) -> T?) -> Bool {
        depth(of: node, parent: parent) < maxDepth
    }

    /// Whether `node` can be moved under `newParent` (`nil` = top level) without a cycle,
    /// exceeding `maxDepth`, or being a no-op.
    static func canMove<T: Equatable>(_ node: T, to newParent: T?, parent: (T) -> T?, children: (T) -> [T]) -> Bool {
        guard parent(node) != newParent else { return false }
        guard let newParent else { return true }
        guard newParent != node, !isAncestor(node, of: newParent, parent: parent) else { return false }
        return depth(of: newParent, parent: parent) + height(of: node, children: children) <= maxDepth
    }

    /// `node` followed by all its descendants, parents before children.
    static func subtree<T>(of node: T, children: (T) -> [T]) -> [T] {
        [node] + children(node).flatMap { subtree(of: $0, children: children) }
    }

    /// Depth-first rows for menus; `level` is 0 for roots.
    static func flatten<T>(_ roots: [T], children: (T) -> [T]) -> [(node: T, level: Int)] {
        func visit(_ node: T, _ level: Int) -> [(node: T, level: Int)] {
            [(node, level)] + children(node).flatMap { visit($0, level + 1) }
        }
        return roots.flatMap { visit($0, 0) }
    }
}

/// Drag-and-drop payload for notes and folders, carried as a string so no custom UTType is needed.
enum DragPayload: Equatable {
    case note(PersistentIdentifier)
    case folder(PersistentIdentifier)

    private static let notePrefix = "notesclone-note:"
    private static let folderPrefix = "notesclone-folder:"

    var string: String {
        let (prefix, id) = switch self {
        case .note(let id): (Self.notePrefix, id)
        case .folder(let id): (Self.folderPrefix, id)
        }
        return prefix + ((try? JSONEncoder().encode(id)) ?? Data()).base64EncodedString()
    }

    init?(_ string: String) {
        func decode(_ prefix: String) -> PersistentIdentifier? {
            guard string.hasPrefix(prefix),
                  let data = Data(base64Encoded: String(string.dropFirst(prefix.count)))
            else { return nil }
            return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
        }
        if let id = decode(Self.notePrefix) {
            self = .note(id)
        } else if let id = decode(Self.folderPrefix) {
            self = .folder(id)
        } else {
            return nil
        }
    }
}
