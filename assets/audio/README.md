# Audio Assets

Sourced WAV files live in `sfx/` and `bgm/` under the exact filenames `AudioManager.gd` expects.
Every file is **16-bit mono 44.1kHz PCM** (required for runtime BGM loop math).

Regenerate from the manifest:

```bash
# Stage packs under /tmp/syngrid-audio-src per tools/audio_source_manifest.json, then:
python3 tools/import_sourced_audio.py --staging /tmp/syngrid-audio-src
```

Provenance: `CREDITS.md`. Procedural fallback generator remains at `tools/generate_placeholder_audio.py`
if you need to reset placeholders locally.

Verification:

```bash
godot --headless --path . --import
godot --headless --path . --quit-after 120
godot --headless --path . scenes/audio/AudioPreviewHarness.tscn
```
