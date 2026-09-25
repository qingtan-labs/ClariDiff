# Changelog

All notable changes to ClariDiff are documented here.

## 1.0.0 — 2026-09-25

Initial macOS release.

### Added

- Native SwiftUI three-column comparison workspace with paste, clipboard, file selection, and drag-and-drop.
- Structured comparison for JSON, JSONL/NDJSON, YAML, TOML, XML, and CSV.
- Object-order independence; positional, unordered, and keyed-array modes.
- Ignored JSON Pointer paths with wildcard segments, numeric tolerance, and string normalization.
- File-level source comparison for Vue, React JSX/TSX, JavaScript/TypeScript, Svelte, Astro, MDX, HTML/CSS and common back-end languages.
- Content-block comparison for text, Markdown, RTF, DOCX, and text-based PDF.
- Change filters, path search, JSON Pointer copy, and Markdown report export.
- Standalone Universal 2 `claridiff` CLI with stable CI exit codes.
- Shareable `.claridiff.yml` rules and English/Simplified Chinese interface.
- Local-only operation with no account, analytics, cloud service, or data upload.

### Known limitations

- macOS 13 or later only.
- Release is ad-hoc signed and not Apple-notarized.
- Source comparison is not yet AST-level and compares one file pair at a time.
- Scanned PDFs, encrypted documents, images, and visual layout comparison are unsupported.
