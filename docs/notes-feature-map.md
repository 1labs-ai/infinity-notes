# Apple Notes (macOS) — MVP feature map for a clean-room SwiftUI replica

Target: `/System/Applications/Notes.app` — `com.apple.Notes` 4.13 (3146.121.7), LSMinimumSystemVersion 26.5,
host macOS 26.5.1, NSPrincipalClass `ICMApplication`, NSMainNibFile `MainMenu` (Info.plist via `plutil -p`).
Static only: Notes was not run, no user data was read, no code or assets copied. Only structure and UI strings are recorded here.

## Evidence index
| ID | What |
|---|---|
| E1 `ev_0263fc0ea7ca27a75d54ea8c05040dfc49054f305cf3538aa1ee90d1122988c1` | `inspect-artifact` bundle graph: 344 nodes / 573 edges, root sha256 `083a0ff1…` |
| E2 `ev_55b228122542df322ea094b885e05dd1fba6e2893f15683d2f3e9c7bd5561609` | `decode-interface-builder` on Notes.app: first 64 nibs (alphabetical, includes PlugIns). 45 were omitted by the hard max of 64 |
| E3 `ev_82043270d26c66eeae477a8c7c468fa76e55cbae1e135f42bd6ddaf2c3ce2cf3` | Same decoder on a scratch subset bundle (byte-identical copies) holding the omitted MainMenu, TK2 editor, search, text-style and Pad nibs. MainMenu.nib sha256 `dd2a191f…` matches the original |
| E4 `ev_ba1f452f665b3a70257fb824979e742abbef5f96006463f4376975210bdc0e45` | Subset decode of `Settings.storyboardc` (plus editor and Pad nibs again) |
| L-App | `Contents/Resources/Localizable.loctable` (`en`), which is inside the bundle |
| L-NS | `/System/Library/PrivateFrameworks/NotesShared.framework/.../Localizable.loctable` (`en`). This sits outside the bundle but is linked by the Notes binary (`otool -L`) |
| S-Bin | `strings` on `Contents/MacOS/Notes`, giving class and identifier names only |

Tags: **OBSERVED** means seen directly in the cited evidence. **INFERRED** means reasoned from names or strings, not seen. **UNKNOWN** means not established.

---
## 1. Window / layout
- **OBSERVED** Main window: `ICMMainWindowController` / `ICMMainWindow`, title "Notes" (E2, ICMMainWindowController.nib). The nib has only 9 objects, so the split view and toolbar are built in code.
- **OBSERVED** Three content controllers, each in its own nib: `ICMFolderListController` (sidebar, `ICMFolderListOutlineView` + `ICMFolderListTreeController`), `ICMNoteListController` (`ICMNoteListTableView`), and `ICMTK2NoteEditorController` (TextKit 2 editor) (E2, E3). An older `PadView`/`NoteHTMLEditorView` (a WebView) exists for legacy HTML notes (E3).
- **OBSERVED** Gallery mode: `ICMNoteGridController` (`ICMNoteGridCollectionView`, `ICMNoteGridFlowLayout`) with placeholder "No Notes" (E2).
- **OBSERVED** View modes in the View menu: "as List" ⌘1 `viewNotesAsList:` and "as Gallery" ⌘2 `viewNotesAsGrid:` (E3 MainMenu). Strings "List View", "Gallery View", "View as Gallery", "View notes as list" (L-App).
- **OBSERVED** Sidebar toggle: View > "Hide Folders" ⌃⌘S `toggleFolderListHidden:`. The label switches between "Hide Folders" and "Show Folders" (E3, L-App).
- **OBSERVED** Single-note window: `ICMSingleNoteWindowController` / `SingleNoteWindow` (E3). It is opened by "Open Note in New Window" or by double-clicking a row (`showSelectedNotesInSingleWindows:`, E2).
- **OBSERVED** Toolbar item classes (S-Bin): `ICMFoldersToolbarItem`, `ICMViewModeToolbarItem`, `ICMDeleteToolbarItem`, `ICMNewNoteToolbarItem`, `ICMFormatToolbarItem`, `ICMChecklistToolbarItem`, `ICMTableToolbarItem`, `ICMMediaToolbarItem`, `ICMAttachmentsToolbarItem`, `ICMLinkToolbarItem`, `ICMLockToolbarItem`, `ICMShareToolbarItem`, `ICMCollaborationToolbarItem`, `ICMSearchToolbarItem`, `ICMNoteListOptionsToolbarItem`, `ICMAddFolderToolbarItem`, `ICMZoomToolbarItem`, `ICMNoteGridBackToolbarItem`. Matching labels in L-App: "Folders", "View", "Delete", "New Note", "Format", "Checklist", "Table", "Media", "Attachments", "Link", "Lock", "Share", "Collaborate", "Search", "Add Folder".
- **UNKNOWN** Toolbar item order. It is set in code (`_standardToolbarIdentifiers`, S-Bin) and was not decompiled. **INFERRED** for the MVP, from the class set: sidebar column [Folders toggle] | list column [View mode, Delete] | editor column [New Note, Format(Aa), Checklist, Table, …, Search at the trailing edge]. Check the order against the running app manually.
- **OBSERVED** The toolbar is user-customizable: View > "Hide Toolbar", "Customize Toolbar…" (E3).

## 2. Sidebar (folders)
- **OBSERVED** Account section headers: `ICMAccountHeaderTableCellView` (E2). Account names in L-NS: "iCloud", "On My Mac". The Settings checkbox reads "Enable the On My Mac account" (E4).
- **OBSERVED** Special folders in L-NS: "Notes" (the default folder) and "Recently Deleted". Also "All Notes", "All %@", "All Accounts" (L-App). Out of MVP scope: Shared, Quick Notes, Math Notes, Call Notes, Smart Folders, Tags.
- **OBSERVED** Folder row (`ICMFolderListFolderTableCellView`, E2) outlets: `imageView`, `titleLabel`, `countLabel`, `actionMenuButton`, `folderSharedButton`. View > "Show Note Count" `toggleFolderListShowsNoteCount:` (E3).
- **OBSERVED** Folder context menu ("Folder Context Menu", E2 ICMFolderListController.nib): "New Folder" (`addNewSubfolder:`), "Rename Folder" (`renameFolder:`), "Delete Folder" (`delete:`), "Share Folder", "Manage Shared Folder", "Show Folder Activity", "Import Archive…", "Export Archive…", "Convert to Smart Folder", "Edit Smart Folder", a "Sort By" submenu (see §3), a "Group By Date" submenu, and "Copy UUID".
- **OBSERVED** Bottom-of-sidebar button: `ICMFolderNewFolderButton` → `addNewFolderButtonAction:`, label "New Folder". Accessibility strings "Create a folder", "Create new folder", "Create a new folder for your notes." Sidebar title "Folders" (E2).
- **OBSERVED** New-folder sheet (`FolderComposerViewController`, E2): header "New Folder", field label "Name:", checkbox "Make into Smart Folder", buttons "Cancel" / "OK".
- **OBSERVED** Menu command: File > "New Folder" ⇧⌘N `addNewFolder:` (E3).
- **OBSERVED** Folder validation strings (L-App/L-NS): "Folder names can’t be blank.", "Duplicate folder name.", "Folder names can’t be longer than %lu characters.", "Can’t rename Notes folder.", "Can’t rename Recently Deleted folder.", "Unable to rename Notes and Recently Deleted folders.", "Notes is limited to %lu levels of folders." (plural form).
- **OBSERVED** Delete-folder strings (L-App): undo name "Delete Folder" (`DELETE_FOLDER_UNDO_STRING`), "Delete %lu Folders" (one form: "Delete Folder"), "All notes and any subfolders will be deleted.", "Some folders can’t be deleted".
- **OBSERVED** Subfolders exist (`addNewSubfolder:`, "subfolder" strings). **UNKNOWN** The depth limit value; only the `%lu` template was seen.
- **INFERRED** "Notes" and "Recently Deleted" cannot be renamed or deleted (from the error strings above). Rename is inline in the outline view (`ICMFolderListTableCellTextField`, plus Edit > "Rename").

## 3. Notes list
- **OBSERVED** Row view `ICMNoteListCellView` (E2) outlets: `titleTextField`, `dateTextField`, `summaryTextField`, `statusImageView0/1` (pinned/locked/shared badges INFERRED), `activityIndicator`. Variants add `folderNameTextField` + `folderImageView` (shown in search and "All" views, INFERRED), a thumbnail (`…WithImage…`), and participants info.
- **OBSERVED** Snippet fallback when there is no body text: "No additional text" (L-NS, zero form of `NOTE_LIST_*_%lu`). Attachment-only notes show counts such as "%lu attachment(s)" / "%lu photo(s)" (L-NS).
- **OBSERVED** Empty state "No Notes" (E2 ICMNoteListController.nib, ICMNoteGridController.nib). Count strings "%lu Notes" (zero: "No Notes", one: "%lu Note") (L-NS).
- **OBSERVED** List context menu ("Note Context Menu", E2): "Open", "Delete" (`delete:`), "New Note" (`addNote:`).
- **OBSERVED** Sort (View > "Sort By", folder menu, and `ICMNoteListCustomSortHeaderCellView` popup): "Default", "Date Edited", "Date Created", "Title", separator, "Newest First", "Oldest First". Actions `setCustomNoteSortTypeOrder:` / `setCustomNoteSortTypeDirection:` (E2, E3). Each folder can override the global setting.
- **OBSERVED** Global default in Settings > General: "Sort notes by:" with Date Edited / Date Created / Title (E4). Labels "Sorted by Date Edited", "Sorted by Date Created", "Sorted by Title", and "Sort by … (Default)" variants (L-NS).
- **OBSERVED** Date grouping: View > "Group By Date" with "Default" / "On" / "Off" (E3). Settings has "Group notes by date" with help text "When sorted by Date Edited or Date Created, group notes by date." (E4).
- **OBSERVED** Section header strings (L-NS): "Pinned", "Today", "Yesterday", "Previous 7 Days", "Previous 30 Days". **INFERRED** Older notes are grouped by month or year name (date-formatted), since no literal string was found. Headers use `ICMNoteListHeaderCellView` (E2).
- **OBSERVED** Pinned section: `ICMNoteListPinnedNotesHeaderCellView` with a `disclosureButton` → `togglePinned:`, so the section collapses (E2). Header text "Pinned" (L-NS). An unpinned separator exists: `ICMNoteListUnpinnedNotesHeaderCellView`, a11y "Unpinned Notes separator" (L-App).
- **OBSERVED** View > "Expand Section" ⌥⌘→, "Collapse Section" ⌥⌘←, "Expand All Sections" ⌥⇧⌘→, "Collapse All Sections" ⌥⇧⌘← (E3; keys are NSRightArrow/NSLeftArrow function keys).
- **OBSERVED** Gallery has its own section header (`ICMNoteGridSectionHeaderView`) and a Recently Deleted header (`ICMNoteGridTrashFolderHeaderView`) (E2).

## 4. Editor
- **OBSERVED** Format menu paragraph styles (E3 MainMenu, all → `setTextStyle:`): "Title" ⇧⌘T, "Heading" ⇧⌘H, "Subheading" ⇧⌘J, "Body" ⇧⌘B, "Monostyled" ⇧⌘M, "Bulleted List" ⇧⌘7, "Dashed List" ⇧⌘8, "Numbered List" ⇧⌘9, "Block Quote" ⌘' (`toggleBlockQuote:`). (Uppercase key equivalents imply Shift.)
- **OBSERVED** Checklist: "Checklist" ⇧⌘L `toggleTodoStyle:`, "Mark as Checked" ⇧⌘U `toggleTodoDone:`, and a More submenu with "Check All", "Uncheck All", "Move Checked to Bottom", "Delete Checked" (E3). Checklists are MVP-optional.
- **OBSERVED** Format > Font: "Show Fonts" ⌘T, "Bold" ⌘B, "Italic" ⌘I (`addFontTrait:`), "Underline" ⌘U, "Strikethrough" (no shortcut), "Highlight" ⇧⌘E (`emphasis:`), "Bigger" ⌘+, "Smaller" ⌘-, Baseline (Use Default/Superscript/Subscript), "Show Colors" ⇧⌘C, "Copy Style" ⌥⌘C, "Paste Style" ⌥⌘V, "Remove Style" (E3).
- **OBSERVED** Format > Text: "Align Left" ⌘{, "Center" ⌘|, "Justify", "Align Right" ⌘}. Indentation: "Increase" ⌘], "Decrease" ⌘[. "Move Item" Up/Down ⌃⌘↑/↓ (E3).
- **OBSERVED** Toolbar "Aa" style popover: `ICMTK2NoteEditorController.stylePopover` + `styleCollectionView` (E3), with items `ICMTextStylesNamedStyleCollectionViewItem` (named styles) and `ICMTextStylesBIUSCollectionViewItem` (Bold/Italic/Underline/Strikethrough row; "BIUS" INFERRED from the name). The editor context menu "Paragraph Styles" lists Title, Heading, Subheading, Body, Monostyled, Bulleted/Dashed/Numbered List, Block Quote (E3).
- **OBSERVED** Settings "New notes start with:" Title / Heading / Subheading / Body (E4). The first line of a new note gets that style.
- **OBSERVED** Editor date header: `ICMNoteEditorDateView.dateLabel` (E2). Strings "Edited: %@" and "Created: %@" (L-App).
- **OBSERVED** "New Note" is the default title string (L-NS, NotesEditor). "Whether to update the link as the note title changes" and "Use Note Title" (L-App) show the title is derived from content.
- **INFERRED** Note title = the first non-empty line of the body. Snippet = the following text, or "No additional text". **UNKNOWN** The exact trimming and length rules (logic lives in the shared-cache NotesShared, not decompiled).
- **OBSERVED** Edit menu: Undo ⌘Z, Redo ⇧⌘Z, Cut/Copy/Paste, "Paste and Match Style" ⌥⇧⌘V, "Select All" ⌘A, "Add Link…" ⌘K, "Attach File…" ⇧⌘A (E3).

## 5. Search, pin, delete, Recently Deleted
### Search
- **OBSERVED** Search lives in the toolbar (`ICMSearchToolbarItem`, label "Search"). A floating suggestions popup (`ICMSearchFieldFloatingViewController`, `ICMSearchFieldSuggestion*` cells) shows "Suggested Searches" and "Top Hits" (E3, L-App).
- **OBSERVED** Edit > Find > "Note List Search…" ⌥⌘F `searchInNoteList:` (searches all notes). "Find…" ⌘F, "Find and Replace…" ⇧⌘F, "Find Next" ⌘G, "Find Previous" ⇧⌘G, "Use Selection for Find" ⌘E (in-note text finder) (E3).
- **OBSERVED** Separate search controllers `ICMSearchNoteListArrayController` and `ICMSearchNoteGridArrayController` (E2). Empty result: "No Results" / "No matches" (L-App).
- **INFERRED** Results span all folders and accounts and use the "…WithFolderView" row (folder name shown). **UNKNOWN** Matching semantics (prefix vs token, title vs body weighting).

### Pin
- **OBSERVED** File > "Pin Note" `pinOrUnpinCurrentNote:`. The label toggles to "Unpin Note" (L-App), with no default shortcut (E3). Strings "Pin", "Unpin", "Pinned", "Pinned Notes", "Pin Notes" / "Unpin Notes" (L-App, L-NS).
- **OBSERVED** "Unable to pin notes because pinning is not supported for IMAP or Exchange accounts." (L-App)
- **INFERRED** Pinned notes appear in a top "Pinned" section of each folder list. The section is collapsible (`togglePinned:`). Pinned notes sort by the same rule inside the section.

### Delete
- **OBSERVED** Edit > "Delete" ⌘⌫ `delete:`. The same key equivalent is on Edit > "Rename" `rename:`, so they are context-dependent alternates (INFERRED). The toolbar has `ICMDeleteToolbarItem` and the list context menu has "Delete" (E2, E3).
- **OBSERVED** Messages (L-App): "Deleted notes are moved to the Recently Deleted folder.", "Delete Note" / "Delete %lu Notes", "Delete Note?", "Trash Note", "Are you sure you want to delete the selected note(s)?".
- **INFERRED** Deleting from a normal folder moves the note to Recently Deleted with no confirmation. A confirmation alert is shown for shared and locked notes (per the strings).

### Recently Deleted
- **OBSERVED** Retention strings (L-App, also in S-Bin): "You can recover or remove from Recently Deleted within 30 days." and "Deleted notes are removed from your devices after 30 days, which may require Notes to be open. Permanent deletion from iCloud may take up to 40 more days." Plural templates "%d days" / "%d Days" (L-NS) suggest a per-note "N days" remaining label (INFERRED).
- **OBSERVED** List header `ICMNoteListRecentlyDeletedHeaderCellView` with a `titleTextField` (E2). **INFERRED** It shows the 30-day explanatory text above the list.
- **OBSERVED** Actions: "Recover", "Recover Note", "Move to", "Delete All" (L-App). S-Bin has "Delete all action from Recently Deleted Folder".
- **OBSERVED** Permanent delete confirm: "Are you sure you want to delete the note permanently?" / "…the %lu notes permanently?" plus "This note will be deleted. This action cannot be undone." (L-App).
- **OBSERVED** Notes in Recently Deleted are read-only: "Can’t modify a note in Recently Deleted." and "To edit this note, you’ll need to recover it." (L-App).

### Other in-scope commands (E3 MainMenu)
- File: "New Note" ⌘N `addNewNote:`, "Duplicate Note" ⌘D, "Close" ⌘W, "Print…" ⌘P, "Export as" > PDF / Markdown, "Import Markdown...".
- Window: "Notes" ⌘0 `showMainWindow:`. App menu: "Settings…" ⌘,.
- View: "Zoom In" ⇧⌘. , "Zoom Out" ⇧⌘, , "Actual Size" ⇧⌘0, "Enter Full Screen" ⌃⌘F.

## 6. Other useful items
- **OBSERVED** Settings > General (E4, `ICMSettingsControllerGeneral`). MVP-relevant rows are "Default account:", "Sort notes by:", "Group notes by date", "New notes start with:", "Default text size:" (slider), and "Use dark backgrounds for note content". The Format menu also has a per-note "Show Note As Light Background".
- **OBSERVED** "Move Notes to Folder" / "Move to" / "Move Note" (L-App). Drag-and-drop to folders is **INFERRED**.
- **OBSERVED** Account-level "Notes is limited to %lu levels of folders." **INFERRED** Use a small depth cap (for example 4) in the replica.
- **OBSERVED** Scripting dictionary `Contents/Resources/Notes.sdef` and App Intents (`Metadata.appintents`). Intent strings "Creates a new note.", "Pins or unpins notes.", "Delete notes.", "Searches for notes and attachments in Notes." (L-App) confirm the core verbs.
- **UNKNOWN** Data model fields, persistence format, and sync behavior. These were not analyzed, and user data stores were deliberately not read.

## Suggested SwiftUI mapping (design choice, not evidence)
`NavigationSplitView` (sidebar `List` with `OutlineGroup` per account → note `List` with `Section`s Pinned/Today/Yesterday/Previous 7 Days/Previous 30 Days/month → detail `TextEditor(AttributedString)`). `.searchable` in the toolbar. `Commands` that reproduce the shortcuts above. A `Recently Deleted` folder holding notes with a `deletedAt` date and a 30-day purge.

## Coverage notes
- The REA IB decoder's `--max-documents` is capped at 64, which omitted 45 nibs. E3/E4 covered the MVP-relevant omissions. Still unreviewed: smart-folder filter nibs, Startup/WhatsNew, Tag nibs, Password entry, and PlugIns beyond the first 64.
- No native decompiler is configured, so toolbar order, title derivation, search matching, and purge timing logic are UNKNOWN or INFERRED.
- English values come from Base nib `NSDev` strings and the `en` loctable entries. NotesEditor's loctable has no `en`, so its keys (US English) were used.
