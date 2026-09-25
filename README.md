# ClariDiff

[简体中文](README.zh-Hans.md) · English

> Compare anything. See what matters.

![ClariDiff app icon](Assets/ClariDiff-icon-master.png)

ClariDiff is an open-source, local-first comparison tool for macOS. It understands structured data, aligns source code without cascading line noise, and compares documents by meaningful content blocks. Files stay on your Mac: there is no account, analytics, cloud service, or upload.

**Local · Open source · Data, code, and documents · English & 简体中文**

[Download 1.0.0](https://github.com/qingtan-labs/ClariDiff/releases/latest) · [中文说明](README.zh-Hans.md) · [Report a bug](https://github.com/qingtan-labs/ClariDiff/issues)

## Download

| Version | System | Architecture | Download |
|---|---|---|---|
| 1.0.0 | macOS 13 Ventura or later | Apple silicon + Intel (Universal 2) | [ClariDiff-1.0.0-Universal.dmg](https://github.com/qingtan-labs/ClariDiff/releases/download/v1.0.0/ClariDiff-1.0.0-Universal.dmg) |

The standalone Universal 2 CLI and `SHA256SUMS` are available on the [Releases page](https://github.com/qingtan-labs/ClariDiff/releases/latest).

> **Signing status:** 1.0.0 is ad-hoc signed and is not Apple-notarized. On first launch, Control-click ClariDiff in Applications and choose **Open**. Never disable Gatekeeper. See the [safe installation guide](docs/INSTALL.md).

## What it compares

| Category | Formats | Comparison behavior |
|---|---|---|
| Structured data | JSON, JSONL/NDJSON, YAML, TOML, XML, CSV | Object order, keyed/unordered arrays, ignored paths, numeric tolerance, string normalization |
| Front-end source | Vue, React JSX/TSX, JavaScript/TypeScript, Svelte, Astro, MDX, HTML, CSS/Sass/Less/Stylus/PostCSS, GraphQL | Ordered content-block alignment; insertions do not shift every following line |
| Other source code | Swift, Python, Java, Kotlin, Go, Rust, C/C++, C#, Ruby, PHP, Shell, SQL, and more | Ordered content-block alignment with whitespace normalization |
| Documents | TXT, Markdown, RTF, DOCX, text-based PDF | Headings, paragraphs, list items, table rows, and text blocks |
| Fallback | Any decodable text file | Ordered text-block comparison |

Scanned PDFs, encrypted documents, image diffs, and visual layout comparison are not supported in 1.0.0.

Source-code comparison in 1.0.0 is file-level, syntax-aware-by-format block alignment rather than a language AST comparison. It does not yet treat import reordering or equivalent refactors as identical, and it does not compare whole folders or dependency graphs.

## Highlights

- Native SwiftUI three-column workspace with paste, clipboard, file picker, and drag-and-drop.
- Automatic format detection with syntax errors shown next to the affected input.
- Structural JSON/JSONL/YAML/TOML/XML/CSV comparison instead of line-by-line noise.
- Array modes: positional, unordered, or object matching by a key such as `id`.
- Ignored paths with `*` wildcard segments.
- Absolute and relative number tolerance.
- Optional whitespace, case, date, newline, and numeric-string normalization.
- Document and code alignment based on an LCS sequence engine.
- Added, removed, modified, and type-changed filters plus path search.
- Markdown report export and a standalone `claridiff` CLI.
- English and Simplified Chinese UI.
- No analytics, account, network request, or data upload.

## Quick start

1. Download and open the DMG.
2. Drag ClariDiff into Applications.
3. Control-click ClariDiff and choose **Open** on the first launch.
4. Drop or paste the two files to compare.
5. Adjust rules when order, volatile fields, or numeric tolerance should be ignored.

## CLI

```bash
chmod +x claridiff-1.0.0-macos-universal
sudo install claridiff-1.0.0-macos-universal /usr/local/bin/claridiff
claridiff before.yaml after.yaml
```

Ignore volatile structured paths:

```bash
claridiff old.json new.json \
  --ignore /updatedAt \
  --ignore /requestId
```

Match array objects by `id`:

```bash
claridiff old.yaml new.yaml --array-key /users=id
```

Generate a CI-friendly Markdown report:

```bash
claridiff expected.docx actual.docx \
  --config .claridiff.yml \
  --format markdown \
  --output diff-report.md
```

Exit codes are stable: `0` means no meaningful difference, `1` means differences exist, and `2` means an input or configuration error.

## Reproducible rules

```yaml
version: 1

ignore:
  - /updatedAt
  - /items/*/traceId

arrays:
  /users:
    matchBy: id
    order: ignore
  /roles:
    order: ignore

numbers:
  defaultTolerance: 0.001
  relativeTolerancePercent: 0.1

strings:
  trimWhitespace: true
  ignoreCase: false
  normalizeLineEndings: true
  normalizeISODates: false
  coerceNumericStrings: false
```

Commit `.claridiff.yml` with a project so GUI and CLI comparisons use reviewable, repeatable rules.

## Build from source

Requirements: macOS 13 or later and Xcode with the macOS SDK.

```bash
git clone https://github.com/qingtan-labs/ClariDiff.git
cd ClariDiff
swift test
make app
open dist/ClariDiff.app
```

Create the Universal 2 DMG and CLI release assets:

```bash
make release
```

## Architecture

```text
ClariDiffApp        SwiftUI application entry point
└── ClariDiffUI     Workspace, rules, tree diff, export workflow
    └── ClariDiffCore
        ├── Format detection and document extraction
        ├── JSON, JSONL, YAML, TOML, XML, and CSV parsers
        ├── Code/document block alignment
        ├── Semantic structured-data diff engine
        └── Markdown/text report exporter

ClariDiffCLI ──────┘
Tests ─────────────┘
```

## Privacy and security

ClariDiff performs comparisons locally and does not transmit file content. Remove confidential content before attaching samples to public issues. See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). ClariDiff is available under the [MIT License](LICENSE).
