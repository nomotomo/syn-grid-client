#!/usr/bin/env python3
"""Import C10 sprite assets from staged third-party packs or procedural fallbacks.

Reads tools/sprite_source_manifest.json. For each target file, resolves the first
available source under SYNGRID_SPRITE_STAGING (default /tmp/syngrid-sprite-src):

  kenney_game_icons/   — unzip Kenney "Game Icons" (CC0)
  akari21_rpg/         — Akari21 "RPG Icon Pack (200+)" itch.io purchase
  cainos_rpg/          — Cainos "Pixel Art Icon Pack - RPG" (free)

When no staged source exists, writes a 32x32 procedural pixel-art fallback so
ItemCard/StatsHud never show a blank texture during incremental delivery.

Run from repo root:
  python3 tools/import_sourced_sprites.py
  python3 tools/import_sourced_sprites.py --write-credits
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "tools" / "sprite_source_manifest.json"
CREDITS_PATH = ROOT / "assets" / "sprites" / "items" / "CREDITS.md"
DEFAULT_STAGING = Path("/tmp/syngrid-sprite-src")
ICON_SIZE = 32


def _write_png_rgba(path: Path, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    """Write a small RGBA PNG without external deps."""
    h = len(pixels)
    w = len(pixels[0])
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for r, g, b, a in row:
            raw.extend((r, g, b, a))

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def _blank() -> list[list[tuple[int, int, int, int]]]:
    return [[(0, 0, 0, 0) for _ in range(ICON_SIZE)] for _ in range(ICON_SIZE)]


def _set(px: list[list[tuple[int, int, int, int]]], x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < ICON_SIZE and 0 <= y < ICON_SIZE:
        px[y][x] = color


def _fill_rect(px, x0: int, y0: int, x1: int, y1: int, color) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            _set(px, x, y, color)


def _procedural(name: str) -> list[list[tuple[int, int, int, int]]]:
    px = _blank()
    teal = (0, 245, 212, 255)
    purple = (122, 47, 190, 255)
    gold = (242, 199, 64, 255)
    silver = (192, 192, 200, 255)
    bronze = (180, 120, 60, 255)
    steel = (170, 175, 185, 255)
    wood = (120, 80, 50, 255)
    red = (217, 26, 26, 255)

    if name == "procedural_coin":
        for y in range(8, 24):
            for x in range(8, 24):
                if (x - 16) ** 2 + (y - 16) ** 2 <= 64:
                    _set(px, x, y, gold)
        for x in range(13, 19):
            _set(px, x, 14, (40, 30, 10, 255))
            _set(px, x, 17, (40, 30, 10, 255))
    elif name == "procedural_heart":
        for y in range(10, 22):
            for x in range(8, 24):
                dx = abs(x - 12) if x < 16 else abs(x - 20)
                if dx + max(0, y - 14) < 6:
                    _set(px, x, y, red)
    elif name == "procedural_trophy":
        _fill_rect(px, 12, 8, 19, 10, gold)
        _fill_rect(px, 10, 10, 21, 18, gold)
        _fill_rect(px, 14, 18, 17, 22, gold)
        _fill_rect(px, 11, 22, 20, 24, gold)
    elif name == "procedural_badge_gold":
        for y in range(6, 26):
            for x in range(6, 26):
                if (x - 16) ** 2 + (y - 16) ** 2 <= 81:
                    _set(px, x, y, gold)
    elif name == "procedural_badge_silver":
        for y in range(6, 26):
            for x in range(6, 26):
                if (x - 16) ** 2 + (y - 16) ** 2 <= 81:
                    _set(px, x, y, silver)
    elif name == "procedural_badge_bronze":
        for y in range(6, 26):
            for x in range(6, 26):
                if (x - 16) ** 2 + (y - 16) ** 2 <= 81:
                    _set(px, x, y, bronze)
    elif name == "procedural_melee_shortsword":
        _fill_rect(px, 15, 4, 16, 22, steel)
        _fill_rect(px, 13, 22, 18, 24, wood)
        _fill_rect(px, 14, 24, 17, 26, purple)
    elif name == "procedural_ranged_longbow":
        for y in range(8, 24):
            _set(px, 10 + (y - 16) // 3, y, wood)
            _set(px, 22 - (y - 16) // 3, y, wood)
        _set(px, 16, 12, teal)
    elif name == "procedural_arcane_arcane_staff":
        _fill_rect(px, 15, 6, 16, 26, wood)
        for y in range(4, 10):
            for x in range(12, 20):
                if (x - 16) ** 2 + (y - 7) ** 2 <= 12:
                    _set(px, x, y, purple)
    elif name == "procedural_shield_iron_buckler":
        for y in range(6, 26):
            for x in range(6, 26):
                if (x - 16) ** 2 + (y - 16) ** 2 <= 81:
                    _set(px, x, y, steel)
        _fill_rect(px, 14, 14, 17, 18, purple)
    else:
        raise KeyError(f"Unknown procedural sprite: {name}")
    return px


def _resolve_source(rel: str, staging_roots: list[Path]) -> Path | None:
    for root in staging_roots:
        candidate = root / rel
        if candidate.exists():
            return candidate
    return None


def _import_one(
    target_rel: str,
    sources: dict[str, str],
    staging_roots: list[Path],
    provenance: list[str],
) -> None:
    dst = ROOT / target_rel
    for pack, rel in sources.items():
        if pack == "fallback":
            continue
        src = _resolve_source(f"{pack}/{rel}", staging_roots)
        if src is not None:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            provenance.append(f"| `{target_rel}` | {pack} `{rel}` | staged import |")
            return

    fallback = sources.get("fallback", "")
    pixels = _procedural(fallback)
    _write_png_rgba(dst, pixels)
    provenance.append(
        f"| `{target_rel}` | procedural fallback (`{fallback}`) | pending staged pack |"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-credits", action="store_true")
    parser.add_argument("--staging", type=Path, default=None)
    args = parser.parse_args()

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    env_staging = os.environ.get("SYNGRID_SPRITE_STAGING")
    staging_roots = []
    if args.staging:
        staging_roots.append(args.staging)
    if env_staging:
        staging_roots.append(Path(env_staging))
    staging_roots.append(DEFAULT_STAGING)
    for rel in manifest.get("staging_roots", []):
        staging_roots.append(ROOT / rel)

    provenance: list[str] = []
    for section in ("hud_glyphs", "rank_badges", "item_icons"):
        for target, sources in manifest[section].items():
            _import_one(target, sources, staging_roots, provenance)

    if args.write_credits:
        lines = [
            "# Sprite Credits (C10)",
            "",
            "Provenance for every file under `assets/sprites/items/` and C10 HUD glyphs.",
            "Re-run `python3 tools/import_sourced_sprites.py --write-credits` after staging packs.",
            "",
            "| File | Source | Notes |",
            "|---|---|---|",
            *provenance,
            "",
            "## Pack staging layout",
            "",
            "Drop extracted packs under `/tmp/syngrid-sprite-src/` (or `SYNGRID_SPRITE_STAGING`):",
            "",
            "- `kenney_game_icons/` — [Kenney Game Icons](https://kenney.nl/assets/game-icons) (CC0)",
            "- `akari21_rpg/` — Akari21 RPG Icon Pack (200+) itch.io purchase",
            "- `cainos_rpg/` — [Cainos Pixel Art Icon Pack - RPG](https://cainos.itch.io/pixel-art-icon-pack-rpg)",
            "",
            "## Licenses",
            "",
            "- Kenney Game Icons: CC0, no attribution required",
            "- Cainos Pixel Art Icon Pack: commercial use OK, credit appreciated not required",
            "- Akari21 RPG Icon Pack: commercial use per itch.io license; keep receipt in `LICENSE-akari21.txt`",
            "",
        ]
        CREDITS_PATH.parent.mkdir(parents=True, exist_ok=True)
        CREDITS_PATH.write_text("\n".join(lines), encoding="utf-8")
        print(f"Wrote {CREDITS_PATH}")

    print(f"Imported {len(provenance)} sprite(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
