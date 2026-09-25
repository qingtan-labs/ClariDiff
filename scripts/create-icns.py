#!/usr/bin/env python3
"""Build a modern ICNS container from a standard macOS .iconset directory."""

from pathlib import Path
import struct
import sys


CHUNKS = (
    (b"icp4", "icon_16x16.png"),
    (b"icp5", "icon_32x32.png"),
    (b"ic11", "icon_16x16@2x.png"),
    (b"icp6", "icon_32x32@2x.png"),
    (b"ic12", "icon_32x32@2x.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic13", "icon_128x128@2x.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic14", "icon_256x256@2x.png"),
    (b"ic10", "icon_512x512@2x.png"),
)


def build(iconset: Path, output: Path) -> None:
    chunks = []
    for chunk_type, filename in CHUNKS:
        payload = (iconset / filename).read_bytes()
        chunks.append(chunk_type + struct.pack(">I", len(payload) + 8) + payload)
    body = b"".join(chunks)
    output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: create-icns.py INPUT.iconset OUTPUT.icns")
    build(Path(sys.argv[1]), Path(sys.argv[2]))
