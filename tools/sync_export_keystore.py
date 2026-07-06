#!/usr/bin/env python3
"""Sync signing credentials from environment into export_presets.cfg.

Godot reads keystore paths only from export_presets.cfg, not from .env.
The Makefile calls this before apk-debug/apk-release so .env stays the
single source of truth and stale preset values cannot silently sign releases.

Usage (from repo root):
  python3 tools/sync_export_keystore.py --debug
  python3 tools/sync_export_keystore.py --release
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRESET_PATH = ROOT / "export_presets.cfg"

FIELD_ENV = {
    "keystore/debug": "ANDROID_DEBUG_KEYSTORE_PATH",
    "keystore/debug_user": "ANDROID_DEBUG_KEYSTORE_USER",
    "keystore/debug_password": "ANDROID_DEBUG_KEYSTORE_PASS",
    "keystore/release": "KEYSTORE_PATH",
    "keystore/release_user": "KEYSTORE_ALIAS",
    "keystore/release_password": "KEYSTORE_PASS",
}


def _set_field(text: str, field: str, value: str) -> str:
    pattern = rf'^({re.escape(field)}=")(.*)(")\s*$'
    replacement = rf'\1{value}\3'
    new_line, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count == 0:
        raise ValueError(f"Field {field} not found in {PRESET_PATH}")
    return new_line


def sync(mode: str) -> None:
    if not PRESET_PATH.exists():
        print(f"Missing {PRESET_PATH} — copy export_presets.cfg.example first.", file=sys.stderr)
        raise SystemExit(1)

    fields: list[str]
    if mode == "debug":
        fields = ["keystore/debug", "keystore/debug_user", "keystore/debug_password"]
    else:
        fields = ["keystore/release", "keystore/release_user", "keystore/release_password"]

    text = PRESET_PATH.read_text(encoding="utf-8")
    for field in fields:
        env_key = FIELD_ENV[field]
        value = os.environ.get(env_key, "")
        if not value:
            print(f"{env_key} not set — cannot sync {field}", file=sys.stderr)
            raise SystemExit(1)
        text = _set_field(text, field, value)

    PRESET_PATH.write_text(text, encoding="utf-8")
    print(f"Synced {mode} keystore fields into {PRESET_PATH.name}")


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--debug", action="store_true")
    group.add_argument("--release", action="store_true")
    args = parser.parse_args()
    sync("debug" if args.debug else "release")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
