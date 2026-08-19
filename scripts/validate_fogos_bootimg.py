#!/usr/bin/env python3
"""Validate the FogOS Android boot image structure created by create_bootimg.sh."""

from __future__ import annotations

import argparse
import hashlib
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

FOOTER_FORMAT = ">4sIIQQQ28s"
VBMETA_FORMAT = ">4sIIQQI" + ("Q" * 11) + "II48s80s"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def unpack_kernel(unpack_tool: Path, image: Path, output_dir: Path) -> Path:
    subprocess.run(
        [sys.executable, str(unpack_tool), "--boot_img", str(image), "--out", str(output_dir)],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    kernel = output_dir / "kernel"
    if not kernel.is_file():
        raise RuntimeError(f"unpack_bootimg did not produce {kernel}")
    return kernel


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--boot", required=True, type=Path)
    parser.add_argument("--kernel", required=True, type=Path)
    parser.add_argument("--unpack-tool", required=True, type=Path)
    args = parser.parse_args()

    image = args.boot.read_bytes()
    if len(image) < 64 + 256:
        raise RuntimeError("boot image is too small to contain AVB vbmeta and footer")

    magic, major, minor, original_size, vbmeta_offset, vbmeta_size, _ = struct.unpack(
        FOOTER_FORMAT, image[-64:]
    )
    assert magic == b"AVBf", f"unexpected AVB footer magic: {magic!r}"
    assert (major, minor) == (1, 0), f"unexpected AVB footer version: {major}.{minor}"
    assert vbmeta_size == 256, f"unexpected minimal vbmeta size: {vbmeta_size}"
    assert vbmeta_offset == original_size, "vbmeta must begin exactly at the original-image boundary"
    assert len(image) == original_size + vbmeta_size + 64, "AVB offsets do not match file size"

    vbmeta = image[vbmeta_offset:vbmeta_offset + vbmeta_size]
    fields = struct.unpack(VBMETA_FORMAT, vbmeta)
    assert fields[0] == b"AVB0", f"unexpected vbmeta magic: {fields[0]!r}"
    assert fields[1:3] == (1, 0), f"unexpected required libavb version: {fields[1:3]}"
    assert fields[3:6] == (0, 0, 0), "minimal vbmeta must have no auth/aux blocks and algorithm NONE"
    assert fields[6:17] == (0,) * 11, "minimal vbmeta must not carry descriptors or rollback data"
    assert fields[17:19] == (1, 0), "vbmeta must set only VERIFICATION_DISABLED and location zero"

    with tempfile.TemporaryDirectory(prefix="fogos-boot-validate-") as temp:
        embedded_kernel = unpack_kernel(args.unpack_tool, args.boot, Path(temp))
        assert sha256(embedded_kernel) == sha256(args.kernel), "boot image kernel payload does not match built Image"

    print("PASS: Android boot header unpacked")
    print("PASS: embedded kernel SHA-256 matches the successful local build")
    print("PASS: AVB footer points to a complete 256-byte vbmeta header")
    print("PASS: vbmeta is AVB_ALGORITHM_NONE with VERIFICATION_DISABLED set")
    print(f"PASS: boot image size {len(image)} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
