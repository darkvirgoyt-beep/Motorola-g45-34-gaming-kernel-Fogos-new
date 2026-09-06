#!/usr/bin/env python3
"""Validate the safe, compatibility-focused FogOS release configuration.

This checker intentionally fails closed. It reports missing performance
foundations and rejects settings that would bypass Android vendor or thermal
safety contracts. It does not modify the supplied configuration.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED = {
    "CONFIG_PREEMPT": "y",
    "CONFIG_PREEMPTION": "y",
    "CONFIG_UCLAMP_TASK": "y",
    "CONFIG_CPU_FREQ_GOV_SCHEDUTIL": "y",
    "CONFIG_ZSMALLOC": "y",
    "CONFIG_ZRAM": {"y", "m"},
    "CONFIG_NET_SCH_FQ": "y",
    "CONFIG_TCP_CONG_BBRPLUS": {"y", "m"},
    "CONFIG_LTO": "y",
    "CONFIG_CFI_CLANG": "y",
    "CONFIG_FOGOS_PROFILE": "y",
}

EXACT = {
    "CONFIG_HZ": "250",
    "CONFIG_NR_CPUS": "8",
}

FORBIDDEN_ENABLED = {
    "CONFIG_KSU",
    "CONFIG_KERNELSU",
    "CONFIG_FOGOS_UNSAFE_OVERCLOCK",
    "CONFIG_FOGOS_DISABLE_THERMAL",
}

FORBIDDEN_TEXT = re.compile(
    r"(?:scaling_(?:min|max)_freq|force_clk_on|force_no_nap|thermal-governor\s*=\s*\"user_space\"|temperature\s*=\s*<125000>)"
)


def parse_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("CONFIG_") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value.strip()
        elif line.startswith("# CONFIG_") and line.endswith(" is not set"):
            key = line[2:-11]
            values[key] = "n"
    return values


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path, help="kernel .config or defconfig to validate")
    args = parser.parse_args()
    if not args.config.is_file():
        print(f"error: configuration not found: {args.config}", file=sys.stderr)
        return 2

    values = parse_config(args.config)
    errors: list[str] = []
    for key, expected in REQUIRED.items():
        actual = values.get(key, "n")
        accepted = expected if isinstance(expected, set) else {expected}
        if actual not in accepted:
            errors.append(f"{key}: expected {'/'.join(sorted(accepted))}, got {actual}")
    for key, expected in EXACT.items():
        actual = values.get(key, "unset")
        if actual != expected:
            errors.append(f"{key}: expected {expected}, got {actual}")
    for key in sorted(FORBIDDEN_ENABLED):
        if values.get(key, "n") not in {"n", "unset"}:
            errors.append(f"{key}: must be disabled, got {values[key]}")

    raw = args.config.read_text(encoding="utf-8", errors="replace")
    for match in FORBIDDEN_TEXT.finditer(raw):
        errors.append(f"unsafe tuning token found: {match.group(0)}")

    if errors:
        print(f"FogOS release config FAILED: {args.config}")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"FogOS release config OK: {args.config}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
