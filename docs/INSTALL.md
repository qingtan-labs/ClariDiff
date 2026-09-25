# Install ClariDiff 1.0.0 safely

ClariDiff 1.0.0 supports macOS 13 Ventura or later on Apple silicon and Intel Macs.

## Verify the download

Download the DMG and `SHA256SUMS` from the same [GitHub Release](https://github.com/qingtan-labs/ClariDiff/releases/tag/v1.0.0), then run:

```bash
cd ~/Downloads
shasum -a 256 ClariDiff-1.0.0-Universal.dmg
grep 'ClariDiff-1.0.0-Universal.dmg' SHA256SUMS
```

The two hexadecimal values must match. If they do not, delete the download.

## Install the app

1. Open `ClariDiff-1.0.0-Universal.dmg`.
2. Drag **ClariDiff** to the **Applications** shortcut.
3. In Finder, open Applications.
4. Control-click **ClariDiff**, choose **Open**, then confirm **Open**.

The extra first-launch step is required because 1.0.0 is ad-hoc signed and not Apple-notarized. Do not disable Gatekeeper globally and do not use commands that remove quarantine from every application.

## Install the CLI

Verify the CLI against `SHA256SUMS`, then:

```bash
chmod +x claridiff-1.0.0-macos-universal
sudo install claridiff-1.0.0-macos-universal /usr/local/bin/claridiff
claridiff --version
```

Expected output: `claridiff 1.0.0`.

## Uninstall

Move `ClariDiff.app` from Applications to Trash. If installed, remove only the CLI file:

```bash
sudo rm /usr/local/bin/claridiff
```

ClariDiff does not create a cloud account or remote copy of your data.
