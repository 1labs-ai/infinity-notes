# Contributing to Infinity Notes

Thanks for helping build Infinity Notes. Everyone is welcome, whether you're
fixing a typo, reporting a bug, or shipping a feature.

## Ground rules

- **Clean-room only.** Infinity Notes is an original implementation. Never copy
  Apple source code, images, icons, or other assets into this repository. Matching
  behavior and UI wording is fine; copying artwork or code is not.
- **One change per pull request.** Small, focused PRs get reviewed fastest.
- **Be kind.** This project follows our [Code of Conduct](CODE_OF_CONDUCT.md).

## Finding something to work on

- Issues labeled [`good first issue`](https://github.com/1labs-ai/infinity-notes/labels/good%20first%20issue)
  are scoped for newcomers.
- Issues labeled [`help wanted`](https://github.com/1labs-ai/infinity-notes/labels/help%20wanted)
  are bigger features we'd love help with.
- Comment on an issue before starting so two people don't build the same thing.
- For a new idea, open a feature request first and agree on scope before writing a
  lot of code.

## Development setup

Requirements: macOS 15+, Xcode 16+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/<you>/infinity-notes.git
cd infinity-notes
xcodegen generate
open InfinityNotes.xcodeproj   # Run with ⌘R, test with ⌘U
```

The Xcode project is generated from `project.yml` and is not committed. If you add,
remove, or rename files, run `xcodegen generate` again. Change build settings in
`project.yml`, not in Xcode.

Run the tests from the command line:

```bash
xcodebuild -project InfinityNotes.xcodeproj -scheme InfinityNotes -derivedDataPath build test
```

## Making a change

1. Fork the repo and create a branch from `main` (`feat/checklists`, `fix/search-crash`).
2. Make your change. Match the style of the surrounding code.
3. Put logic that doesn't need UI (text processing, grouping, folder rules) in plain
   Swift types and add unit tests for it in `Tests/`.
4. Run the tests and try the change in the running app.
5. Open a pull request and fill in the template, including a screenshot or short
   recording for any UI change.

## Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add checklist formatting
fix: keep note selection after deleting a folder
docs: explain the folder depth limit
```

## Code layout

See the [Layout section of the README](README.md#layout) for where things live.
`docs/notes-feature-map.md` lists Apple Notes behaviors we observed, which is a good
reference when matching how a feature should feel.

## Reporting bugs and security issues

- Bugs: open an issue using the bug report template.
- Security vulnerabilities: please don't open a public issue. See [SECURITY.md](SECURITY.md).

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
