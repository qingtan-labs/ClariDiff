# Security Policy

## Supported version

Security fixes are provided for the latest published release.

## Report a vulnerability

Please do not disclose a suspected vulnerability in a public issue. Use GitHub's **Private vulnerability reporting** on this repository's Security tab. Include the affected version, macOS version, reproduction steps, impact, and any suggested mitigation.

If private reporting is unavailable, open an issue containing no exploit details and ask the maintainers for a private contact channel.

## Release trust

ClariDiff 1.0.0 is built by the public GitHub Actions workflow, ad-hoc signed, and not Apple-notarized. Release assets include `SHA256SUMS`; verify the checksum before opening a download. Never disable Gatekeeper globally to run ClariDiff.

Dependencies are declared in `Package.swift` and resolved by Swift Package Manager. The application has no account, analytics, cloud sync, or runtime network feature.

## 安全报告

请不要在公开 Issue 中披露漏洞细节。优先使用仓库 Security 页面中的 **Private vulnerability reporting**，并附上受影响版本、macOS 版本、复现步骤、影响与可能的缓解方案。
