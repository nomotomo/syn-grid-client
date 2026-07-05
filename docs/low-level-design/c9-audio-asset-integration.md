# LLD: C9 Audio Asset Integration

Status: Approved 2026-07-05.
Owner: Claude Code (Lead Architect).
Governs: GitHub issue #8.
Depends on: `docs/dependency/ui-audio-assets.md` (asset sourcing decisions), `docs/juice_manual.md` section 5.

## Why this doc exists

`scripts/autoloads/AudioManager.gd` is architecturally complete - cross-fade, on-demand
threaded loading, the LPF fatal-hit sweep, and all 14 SFX methods have shipped since C1/C5.
The fatal-hp-loss trigger is already wired into `RoundEndScene.gd:156` and `:169` (done as
part of C7, not still open as issue #8's original body implies).
What remains is content, not code: replace the procedurally-generated placeholder WAVs in
`assets/audio/` with real sourced files, without breaking the runtime contract the existing
code already depends on.
This doc is the binding spec for that replacement so Cursor doesn't need to reverse-engineer
`AudioManager.gd`'s assumptions from scratch.

## Binding technical constraint: WAV format contract

`AudioManager._load_bgm_stream()` (`scripts/autoloads/AudioManager.gd:130-144`) force-sets loop
points at runtime. For `AudioStreamWAV` it does:

```
stream.loop_begin = 0
stream.loop_end = stream.data.size() / 2   # 16-bit mono frames
```

`stream.data.size()` is a **byte** count. Dividing by 2 is only correct for 16-bit **mono**
PCM. If a sourced file is stereo 16-bit, this produces a loop-end frame index roughly 2x too
large, and the loop point will land past the real audio - causing a glitch or silence at the
seam. `tools/generate_placeholder_audio.py` already produces 16-bit mono 44.1kHz WAV for
exactly this reason.

**Rule for every replacement file (SFX and BGM):**
- 16-bit PCM WAV
- Mono (single channel)
- 44.1kHz sample rate
- Exact filename match to the `SFX_PATHS` / `BGM_PREP` / `BGM_COMBAT` constants in
  `AudioManager.gd:8-26` - do not rename, do not change extension.

OGG or MP3 sources do not hit this bug (`AudioStreamOggVorbis`/`AudioStreamMP3` just set
`.loop = true`, no byte math) - but the filenames are locked to `.wav` per
`docs/dependency/ui-audio-assets.md`, so **convert every sourced file to the format above
before dropping it into `assets/audio/`.** Do not add second code path for OGG just to avoid
a conversion step.

### Conversion tooling note

This machine has no `ffmpeg` (see project memory / prior toolchain audit). Use `afconvert`
(bundled with macOS, no install needed) or Python `wave`/`numpy` (already a project dependency
for `tools/generate_placeholder_audio.py`) to downmix/resample. Example with `afconvert`:

```bash
afconvert -f WAVE -d LEI16@44100 -c 1 input_stereo.wav assets/audio/sfx/sfx_shop_reroll.wav
```

Verify each output with `python3 -c "import wave; w=wave.open(p); print(w.getnchannels(), w.getframerate(), w.getsampwidth())"`
before committing - must print `1 44100 2`.

## Asset sourcing - what to execute

Full rationale lives in `docs/dependency/ui-audio-assets.md`. Summary of what's left to do:

| Keys | Source | Status |
|---|---|---|
| `shop_reroll`, `synergy_link`, `grid_snap`, `item_drag`, `win_round`, `triumph_milestone` | Hove Audio "Free Sci-Fi UI Sound Effects Pack" (itch.io) | Picked - download, pick one file per key, convert, credit |
| `melee_strike`, `ranged_strike`, `arcane_strike`, `crit_hit`, `shield_absorb`, `hp_loss`, `fatal_hp_loss` | OpenGameArt.org, filter CC0, tag "RPG"/"combat"/"fantasy" | Open - needs an actual listen-through against the sound-design column in issue #8's SFX table; pick CC0 only so no `CREDITS.md` entry is legally required, but add one anyway for provenance |
| `bgm_prep.wav`, `bgm_combat.wav` | whitebataudio "Free Cyberpunk Loop Pack" (itch.io) | Candidate - audition all 3 loops; if none differentiate prep (dark/tense/low-BPM) from combat (percussive/energetic) enough, fall back to two separate OpenGameArt CC0 tracks instead of forcing a mismatch |

Do not substitute a different pack for the six already-decided keys without updating
`docs/dependency/ui-audio-assets.md` first - that decision already survived a fit check
against three rejected alternatives.

## `assets/audio/CREDITS.md` - required schema

New file, does not exist yet. One row per sourced file (SFX or BGM), regardless of whether
the license technically requires attribution - this is provenance documentation for future
repo transplants/audits, not just a legal minimum.

```markdown
# Audio Credits

| File | Pack | Creator | Source URL | License |
|---|---|---|---|---|
| sfx_shop_reroll.wav | Free Sci-Fi UI Sound Effects Pack | Hove Audio | https://hoveaudio.itch.io/... | Royalty-free, commercial OK, credit requested |
| bgm_prep.wav | Free Cyberpunk Loop Pack | whitebataudio | https://whitebataudio.itch.io/... | Royalty-free, commercial OK |
```

Every one of the 14 SFX rows and both BGM rows must be present before this issue closes.

## Verification (mandatory before requesting review)

Audio can't be screenshotted, so the existing `SYNGRID_SCREENSHOT` harness pattern doesn't
cover it. Use this sequence instead:

1. `godot --headless --path . --import` - refresh the import cache for the new files.
2. `godot --headless --path . --quit-after 120` - confirm no import/parse errors on any new
   `.wav`.
3. Run each of the five scenes that call `AudioManager` (`GridPrepScene`, `CombatReplayScene`,
   `RoundEndScene`, `LeaderboardScene`, `MainMenu`) through its existing preview harness in the
   editor (not headless) and confirm audibly:
   - BGM cross-fades 0.8s with no pop/click at the loop seam (let a track loop at least once).
   - Every one of the 14 SFX keys is audible on first trigger, not just the second (this
     exercises the on-demand load path - if the first call is silent, `_flush_pending_plays`
     regressed).
   - `play_fatal_hp_loss()` audibly muffles BGM for ~2s then restores it, with no permanent
     filter left on the `BGM` bus (`AudioServer.get_bus_effect_count` should return to its
     pre-call value - check via a print statement during manual QA, remove before commit).
4. Confirm every filename in `assets/audio/{sfx,bgm}/` matches `AudioManager.gd`'s constants
   exactly - a typo here fails silently (`ResourceLoader.exists()` returns false, BGM/SFX just
   never plays, no error).

## Out of scope

No changes to `AudioManager.gd`'s public API, bus setup, or cross-fade/LPF logic are needed -
this is a content swap, not a refactor. If the stereo/mono constraint above turns out to be
wrong in practice (e.g. Godot's `AudioStreamWAV.data` layout differs from this doc's
assumption), stop and flag it back to Claude Code rather than patching around it - that
function is shared by every BGM track, so a wrong fix there is a silent bug for both tracks
at once.
