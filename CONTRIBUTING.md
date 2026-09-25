# Contributing to ClariDiff

Thanks for helping make comparisons clearer.

## Before opening a change

- Search existing issues first.
- For a bug, include a minimal sanitized input pair and the expected result.
- For a new format or comparison rule, describe which representational changes should be ignored and which changes remain meaningful.
- Keep first-version scope focused on two-file comparison for macOS and the shared CLI/core.

## Development

Requirements: macOS 13 or later, Xcode with the macOS SDK, and Swift 5.8 or later.

```bash
git clone https://github.com/qingtan-labs/ClariDiff.git
cd ClariDiff
swift package resolve
swift test
make app
```

Before submitting a pull request:

1. Add or update tests for core behavior.
2. Run `swift test`.
3. Keep English and Simplified Chinese user-facing copy in sync.
4. Do not add analytics, uploads, or network access without an explicit public design discussion.
5. Explain behavior changes and limitations in the pull request.

By contributing, you agree that your contribution is licensed under the repository's MIT License.
