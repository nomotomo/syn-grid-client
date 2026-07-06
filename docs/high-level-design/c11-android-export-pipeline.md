# HLD — C11: Android Export & Release Build Pipeline

Governing PRD: `docs/prd/c11-android-export-pipeline.md`

## Architecture Overview

The pipeline is a linear, locally-run chain with a hard gate at the end.
Nothing here talks to the network or to `../sync-grid` — it is pure build tooling.

```
[export_presets.cfg]  (gitignored, copied from .example, machine-local)
        |
        v
make check  --------->  godot --headless --import   (refresh class cache, catch parse errors)
        |                godot --headless --quit-after N   (boot-check, catch runtime errors)
        v
make apk-debug  ------>  godot --headless --export-debug "Android" export/syn-grid-debug.apk
        |
        v
aapt dump badging  --->  size audit gate  ---(>50MB)--->  asset remediation (audio/sprite conversion)
        |
     (<=50MB)
        v
14-item pre-flight checklist (docs/juice_manual.md §7)  --->  tag release
        |
        v
make apk-release  ---->  godot --headless --export-release "Android" export/syn-grid-release.apk
                          (signed with user-held release keystore, via .env-supplied path/passwords)
```

Two independent gitignored inputs feed the pipeline and must exist locally before it runs: `export_presets.cfg` (Android preset config) and `.env` (keystore paths/passwords for release signing). Both are seeded from checked-in `.example` templates so the shape is documented even though the real values never enter the repo.

## Component Design

### 1. Export preset (`export_presets.cfg`, machine-local; `export_presets.cfg.example` checked in)
Single Android preset holding: package name, min/target SDK, portrait orientation lock, `INTERNET` + `ACCESS_NETWORK_STATE` permissions, and (for debug) a reference to a locally-generated debug keystore path. Because this file already lives in `.gitignore`, every developer generates their own copy from the example — this is the existing repo convention (same shape as a `.env.example` pattern) and this phase follows it rather than introducing a second pattern.

### 2. Secrets (`.env`, machine-local; `.env.example` checked in)
Holds `KEYSTORE_PATH`, `KEYSTORE_PASS`, `KEYSTORE_ALIAS`, `KEYSTORE_ALIAS_PASS` for release signing, plus `ANDROID_DEBUG_KEYSTORE_PATH` for the debug signing identity. The Makefile reads this via a non-fatal include so `make check` and `make apk-debug` still work for a developer who hasn't set up release signing yet.

### 3. Makefile
Three targets only, matching the issue exactly: `check`, `apk-debug`, `apk-release`. `apk-release` is the only target that touches secrets, and it must fail closed (non-zero exit, clear message) if the keystore file or password env vars are missing — it must never fall through to producing an unsigned or debug-signed APK under the release filename. Exact target contract is in the LLD.

### 4. `docs/build.md`
The runbook a new developer follows top-to-bottom: install export templates, generate a debug keystore (low-stakes, regenerable), generate a release keystore (high-stakes — the doc must say explicitly to back it up in two places before the first release build), run `make apk-debug`, run the size audit, interpret the result.

### 5. Size audit
Manual step this phase (no CI, per the local-only decision): `aapt dump badging export/syn-grid-debug.apk`, recorded against the 50MB budget. Godot's WAV importer cannot produce true Ogg Vorbis (it only does IMA-ADPCM on WAV sources), so if the audit forces audio conversion, that requires installing an external encoder at that time — this is intentionally not solved preemptively, per the gated scope decision in the PRD.

## Keystore & Secrets Model

Two distinct signing identities with very different risk profiles:

- **Debug keystore**: low-stakes, regenerable at any time, only used for local install-and-test. Can be scaffolded by Cursor during implementation.
- **Release keystore**: the permanent Play Store signing identity. Losing it means the app can never be updated under that identity again. Generated and held by the user only, outside any AI-assisted session, never touched by Claude Code or Cursor. `docs/build.md` documents the `keytool` command and a mandatory backup step; the pipeline only ever reads its path and password from the gitignored `.env`.

## Trade-offs and Risks

This is build tooling, not a running service, so "5x load spike" doesn't apply directly — the equivalent failure modes are silent corruption, drift, and irrecoverable secret loss. Each is named with its mitigation, per the required adversarial pass.

1. **Godot version drift.** Export templates must exactly match the Godot build used to export (currently 4.7, though `project.godot`'s `config/features` already says 4.7 and the CLAUDE.md stack table still says 4.3 — corrected as part of this phase). A mismatch doesn't always error loudly; it can produce a corrupted or non-installable APK.
   *Mitigation:* `docs/build.md` pins the exact Godot version to install templates for, and the CLAUDE.md stack table is corrected in this phase to stop the drift at the source.

2. **`make check` false positive.** If `--quit` fires before asset import actually finishes (large audio/texture files still importing), the check can report success against a stale or incomplete cache.
   *Mitigation:* `check` runs `--import` to completion first, then a separate `--quit-after N` boot check — not a single bare `--quit`, which is what the issue's literal text suggested but is not sufficient by itself.

3. **Release keystore loss.** Unrecoverable — the app can never be updated under the same Play Store identity again.
   *Mitigation:* keystore generation and custody stays entirely with the user (scope decision #3); `docs/build.md` mandates a two-location backup before the first release build; `make apk-release` fails closed if the keystore file referenced by `.env` doesn't exist, rather than silently doing something else.

4. **Secret leakage via `.env` or shell history.** `.env` is plaintext on disk.
   *Mitigation:* already gitignored; this phase adds `*.jks`/`*.keystore` to `.gitignore` too (currently missing); documented as local-only, with an explicit note that CI secret handling is a distinct concern to solve when the CI follow-up issue is picked up.

5. **No automated size regression gate.** Because CI is deferred, nothing catches an asset-driven APK size regression automatically after this phase — it depends on a human remembering to run the audit before tagging.
   *Mitigation:* the pre-flight checklist item 14 (`APK size under 50MB`) is the explicit, named gate in the tagging process; the CI follow-up issue exists partly to close this human-dependency gap later.

6. **Android SDK tooling drift.** `aapt` isn't bundled with Godot — it comes from the Android SDK build-tools, which can be a different version than what Godot's export templates expect.
   *Mitigation:* `docs/build.md` names the exact required Android SDK components (build-tools, platform-tools) alongside the Godot export template version.

## Cross-References

- LLD: `docs/low-level-design/c11-android-export-pipeline.md` (file manifest, exact Makefile/preset/env contracts, review checklist).
- Juice contract: `docs/juice_manual.md` §7 (the 14-item pre-flight checklist this pipeline gates against).
