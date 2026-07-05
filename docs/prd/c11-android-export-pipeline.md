# PRD — C11: Android Export & Release Build Pipeline

Tracks: [GitHub issue #9](https://github.com/nomotomo/sync-grid-client/issues/9)

## Overview

The client has never been exported to a device.
This phase turns the Godot project into a Godot-4-native, repeatable Android build pipeline: one command produces an installable debug APK, and a second command produces a signed release APK, with a size gate before either is tagged for distribution.

## Goals

- A new developer can go from a fresh clone to an installed debug APK on their own Android device using only `docs/build.md` and `make apk-debug`.
- A release APK can be produced and signed without ever putting the signing key or its password in the repository.
- The APK stays under the 50MB CPI budget, or the pipeline tells you clearly that it didn't and by how much.
- The 14-item `docs/juice_manual.md` pre-flight checklist is the tagging gate, not a suggestion.

## Non-Goals (this phase)

- iOS export. Tracked as a future issue; not part of C11's acceptance criteria.
- CI/CD automation (GitHub Actions or similar). The pipeline must work end-to-end locally first; automating it is a follow-up once the Makefile targets are proven.
- Converting existing WAV audio assets to Ogg Vorbis. This only happens if the size audit in this phase shows the APK actually needs it.
- Play Store listing, store assets, or submission process.

## Background & Constraints

- Target is Android primary (min SDK 24 / Android 7.0, target SDK 34), iOS secondary and out of scope here.
- Portrait 1080x1920, matching the existing `project.godot` display config.
- APK size budget is 50MB, driven by CPI targets in India/SEA.
- The client has no native plugins; all game logic is server-side, so nothing structural should be inflating the APK beyond assets and the engine runtime.
- Local toolchain note: the Godot binary on the dev machine is 4.7, while `project.godot`'s `config/features` also declares `4.7`.
The CLAUDE.md stack table currently says 4.3 — this is stale and is corrected as part of this phase (see HLD).
Export templates must match the exact engine build used, or the export step fails or silently produces a broken package.
- No `ffmpeg` is installed in the current local dev environment. This matters because Godot's WAV importer only supports IMA-ADPCM compression on import — it does not transcode WAV to Ogg Vorbis. Producing real `.ogg` assets requires an external encoder that isn't currently available, which is why OGG migration is gated rather than assumed.
- `.gitignore` already excludes `export/`, `*.apk`, `*.aab`, `export_presets.cfg`, and `.env`. It does **not** yet exclude `*.jks` or `*.keystore` — this is a gap this phase must close (see LLD).

## Scope Decisions

These four calls were made by Claude Code (Lead Architect) per the CLAUDE.md CI/CD and architecture-ownership responsibilities. They are documented here as explicit, revisitable decisions, not silent assumptions.

1. **CI/CD: local-only this phase.** Confirmed with the user. The Makefile is the full deliverable; GitHub Actions automation is deferred to a follow-up issue once `make apk-debug` / `make check` are proven locally.
2. **Audio format: gate on the size audit, don't pre-convert.** Existing WAV SFX/BGM assets from C9 stay as-is. After the first debug APK export, the size audit (`aapt dump badging`) determines whether conversion is actually necessary. If the APK is under 50MB, WAV assets stay and a follow-up issue tracks the OGG migration as tech debt. If over 50MB, conversion happens as part of closing out this phase, and the local dev environment will need an Ogg Vorbis encoder installed at that point (not pre-installed now, since it may not be needed).
3. **Release keystore custody: user-generated and user-held.** Neither Claude Code nor Cursor generates, sees, or handles the real release signing key. `docs/build.md` documents the exact `keytool` command; the developer runs it themselves outside any AI session and stores the `.jks` file and passwords in their own password manager. A throwaway debug keystore (regenerable, no Play Store identity at stake) may be scaffolded during implementation for local testing convenience.
4. **iOS: skipped entirely, not just undocumented.** No export preset, no provisioning docs, no time spent this phase. Tracked as a separate future issue when Android is stable in production.

## Requirements

### Android export setup
- Android export templates installed matching the local Godot 4.7 build exactly.
- A checked-in `export_presets.cfg.example` documenting the exact Android preset values (package name `com.nomotomo.syncgrid`, min SDK 24, target SDK 34, portrait orientation, `INTERNET` + `ACCESS_NETWORK_STATE` permissions). The real `export_presets.cfg` stays gitignored and machine-specific, copied from the example.
- A checked-in `.env.example` documenting the required environment variables for release signing, with the real `.env` gitignored.
- `*.jks` and `*.keystore` added to `.gitignore`.

### Build pipeline
- `Makefile` with `check`, `apk-debug`, `apk-release` targets (see LLD for the exact target contract, including fail-fast behavior on missing keystore/env vars).
- `docs/build.md` covering: installing export templates, generating the debug keystore, generating and safely storing the release keystore, running the first build, and troubleshooting the size audit.

### Size audit
- `aapt dump badging` run against the first successful debug APK export, size recorded in `docs/build.md` or a follow-up doc.
- If over 50MB: audit `assets/` for the largest contributors and convert accordingly (audio first, per the gated decision above).

## Acceptance Criteria

(carried over from issue #9, unchanged)

- `make apk-debug` produces a valid APK that installs on an Android 7+ device.
- APK size is under 50MB.
- All 14 pre-flight checklist items from `docs/juice_manual.md` section 7 pass before the APK is tagged.
- `docs/build.md` documents the full setup for a new developer.
- Keystore and `.env` are in `.gitignore` — never committed.

## Follow-up Issues to File (after this phase merges)

- GitHub Actions CI to build and attach a debug APK per push/PR.
- WAV → Ogg Vorbis migration for all SFX/BGM assets, if not forced by the size audit in this phase.
- iOS export preset and provisioning.
