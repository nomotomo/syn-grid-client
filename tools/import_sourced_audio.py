#!/usr/bin/env python3
"""Import sourced OGG/WAV clips into assets/audio/ as 16-bit mono 44.1kHz WAV.

Reads tools/audio_source_manifest.json and resolves sources from:
  1. SYNGRID_AUDIO_STAGING env var (default /tmp/syngrid-audio-src)
  2. assets/audio/_import_sources/

Run from repo root:
  python3 tools/import_sourced_audio.py
  python3 tools/import_sourced_audio.py --write-credits

Uses macOS afconvert (no ffmpeg required). Verifies every output is 1ch/44100/16-bit.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "tools" / "audio_source_manifest.json"
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
BGM_DIR = ROOT / "assets" / "audio" / "bgm"
CREDITS_PATH = ROOT / "assets" / "audio" / "CREDITS.md"
DEFAULT_STAGING = Path("/tmp/syngrid-audio-src")
SR = 44100


def _resolve_source(rel: str, staging_roots: list[Path]) -> Path:
    for root in staging_roots:
        candidate = root / rel
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"Missing source '{rel}' under staging roots: {staging_roots}")


def _afconvert_mono_wav(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", "LEI16@44100", "-c", "1", str(src), str(dst)],
        check=True,
    )


def _read_mono_wav(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as w:
        if w.getnchannels() != 1 or w.getframerate() != SR or w.getsampwidth() != 2:
            raise ValueError(f"{path} is not 16-bit mono 44.1kHz after conversion")
        frames = w.readframes(w.getnframes())
    return np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0


def _write_mono_wav(path: Path, audio: np.ndarray, peak: float = 0.92) -> None:
    audio = np.asarray(audio, dtype=np.float32)
    mx = float(np.max(np.abs(audio))) if audio.size else 0.0
    if mx > 0:
        audio = audio * (peak / mx)
    pcm = np.clip(audio * 32767.0, -32768, 32767).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def _tile_to_duration(audio: np.ndarray, seconds: float) -> np.ndarray:
    target = int(SR * seconds)
    if audio.size == 0:
        return np.zeros(target, dtype=np.float32)
    reps = int(np.ceil(target / audio.size))
    tiled = np.tile(audio, reps)[:target]
    # Short crossfade at seam to reduce click when Godot loops.
    seam = min(SR // 20, audio.size // 4, target // 8)
    if seam > 8:
        head = tiled[:seam]
        tail = tiled[target - seam : target]
        ramp = np.linspace(0.0, 1.0, seam, dtype=np.float32)
        tiled[:seam] = head * ramp + tail * (1.0 - ramp)
    return tiled


def _verify_wav(path: Path) -> tuple[int, int, int]:
    with wave.open(str(path), "rb") as w:
        return w.getnchannels(), w.getframerate(), w.getsampwidth()


def import_all(staging: Path, write_credits: bool) -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    staging_roots = [staging, ROOT / "assets" / "audio" / "_import_sources"]
    rows: list[dict] = []

    tmp = staging / ".import_tmp"
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True)

    for dest, meta in manifest["sfx"].items():
        src = _resolve_source(meta["source"], staging_roots)
        tmp_wav = tmp / dest
        out = SFX_DIR / dest
        _afconvert_mono_wav(src, tmp_wav)
        shutil.copy2(tmp_wav, out)
        ch, rate, width = _verify_wav(out)
        print(f"SFX {dest}: {ch}ch {rate}Hz width={width} <- {src.name}")
        rows.append({"file": dest, **meta})

    for dest, meta in manifest["bgm"].items():
        src = _resolve_source(meta["source"], staging_roots)
        tmp_wav = tmp / f"_{dest}"
        loop_seconds = float(meta.get("loop_seconds", 36.0))
        _afconvert_mono_wav(src, tmp_wav)
        audio = _read_mono_wav(tmp_wav)
        looped = _tile_to_duration(audio, loop_seconds)
        out = BGM_DIR / dest
        _write_mono_wav(out, looped, peak=0.55)
        ch, rate, width = _verify_wav(out)
        dur = wave.open(str(out), "rb").getnframes() / SR
        print(f"BGM {dest}: {ch}ch {rate}Hz {dur:.1f}s <- {src.name}")
        rows.append({"file": dest, **meta})

    if write_credits:
        _write_credits(rows, manifest)
    print("Import complete.")


def _write_credits(rows: list[dict], manifest: dict) -> None:
    lines = [
        "# Audio Credits",
        "",
        "Provenance for every shipped file under `assets/audio/`.",
        "",
        "Attribution: *Music by Karl Casey @ White Bat Audio* · *UI SFX by Hove Audio (hoveaudio.itch.io)*",
        "",
        "| File | Pack | Creator | Source URL | License | Notes |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        note = row.get("note", "")
        lines.append(
            f"| {row['file']} | {row['pack']} | {row['creator']} | {row['source_url']} | {row['license']} | {note} |"
        )
    lines.extend([
        "",
        "Regenerate this file: `python3 tools/import_sourced_audio.py --staging /tmp/syngrid-audio-src`",
        "",
    ])
    CREDITS_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {CREDITS_PATH.relative_to(ROOT)}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--staging", type=Path, default=Path(os.environ.get("SYNGRID_AUDIO_STAGING", str(DEFAULT_STAGING))))
    parser.add_argument("--write-credits", action="store_true", default=True)
    args = parser.parse_args()

    staging = args.staging
    if not staging.exists():
        print(f"Staging directory missing: {staging}", file=sys.stderr)
        print("Download packs per docs/low-level-design/c9-audio-asset-integration.md", file=sys.stderr)
        return 1
    import_all(staging, args.write_credits)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
