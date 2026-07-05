# Syn-Grid Android Build Guide

Local-only Android export pipeline for Godot **4.7.stable** (must match `project.godot` `config/features`).

## 1. Prerequisites

| Component | Version / path | Notes |
|---|---|---|
| Godot | **4.7.stable** (same build as `godot --version`) | Install from [godotengine.org/download/archive/4.7-stable](https://godotengine.org/download/archive/4.7-stable/) |
| Export templates | **4.7.stable** | Editor → **Manage Export Templates** → install matching templates, or download `Godot_v4.7-stable_export_templates.tpz` and install from file. Templates must land under `~/Library/Application Support/Godot/export_templates/4.7.stable/` with `android_source.zip` at that directory root (not only under a `templates/` subfolder). |
| Java JDK | **17** (OpenJDK 17) | Required for Gradle. Godot → **Editor Settings → Export → Android → Java SDK Path** → e.g. `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`. Java 21+ may fail Gradle with `Unsupported class file major version`. |
| Android SDK | **platform-tools** + **build-tools;34.0.0** + **platforms;android-34** | Godot → **Editor Settings → Export → Android → Android SDK Path**. Homebrew: `brew install --cask android-commandlinetools`, then `sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"`. Default SDK root: `/opt/homebrew/share/android-commandlinetools`. |
| `aapt` | From build-tools 34 | Used for size audit: `$ANDROID_SDK/build-tools/34.0.0/aapt dump badging export/syn-grid-debug.apk` |

## 2. First-time setup

```bash
cp export_presets.cfg.example export_presets.cfg
cp .env.example .env
make setup-android    # installs android/build/ from export templates (headless)
```

Edit `export_presets.cfg` (gitignored):

- Set `keystore/debug`, `keystore/debug_user`, `keystore/debug_password` to your debug keystore (see section 3), or leave blank to use Godot Editor Settings defaults.

Edit `.env` (gitignored) only when preparing release signing (section 4). Copy release keystore paths into `export_presets.cfg` `keystore/release*` fields as well — Godot reads signing paths from the preset, not from `.env`. The Makefile only validates `.env` before `make apk-release`.

## 3. Debug keystore (low-stakes, regenerable)

```bash
mkdir -p keystores
keytool -genkeypair -v \
  -keystore keystores/debug.jks \
  -alias androiddebugkey \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass android -keypass android \
  -dname "CN=Android Debug,O=Syn-Grid,C=US"
```

Point `export_presets.cfg` at `keystores/debug.jks` (absolute path recommended). This identity is for local install-and-test only.

## 4. Release keystore (permanent Play Store identity)

**Do this outside any AI-assisted session.** Losing this keystore means you cannot ship updates under the same Play identity.

```bash
keytool -genkeypair -v \
  -keystore /secure/path/syncgrid-release.jks \
  -alias syncgrid \
  -keyalg RSA -keysize 2048 -validity 10000
```

Back up the `.jks` file and all passwords in **two separate secure locations** before the first release build.

Fill `.env`:

```
KEYSTORE_PATH=/secure/path/syncgrid-release.jks
KEYSTORE_PASS=...
KEYSTORE_ALIAS=syncgrid
KEYSTORE_ALIAS_PASS=...
```

Mirror those values in `export_presets.cfg` `keystore/release*` fields.

## 5. Running the first build

```bash
make check       # --import then 60s boot check
make apk-debug   # depends on check; writes export/syn-grid-debug.apk
```

Expected success: `export/syn-grid-debug.apk` exists; `aapt dump badging` shows `package: name='com.nomotomo.syncgrid'`, `sdkVersion:'24'`, `targetSdkVersion:'34'`, and `INTERNET` + `ACCESS_NETWORK_STATE` permissions.

## 6. Size audit

After the first successful debug export:

```bash
ls -lh export/syn-grid-debug.apk
aapt dump badging export/syn-grid-debug.apk | head -5
```

**Recorded measurement (2026-07-06, arm64-v8a only, debug APK):**

| Metric | Value |
|---|---|
| File size | **78 MB** |
| Budget | 50 MB |
| Status | **Over budget** |

Primary contributors: Godot Android runtime library (~76 MB uncompressed per ABI) and uncompressed WAV SFX/BGM from C9. The preset excludes dev-only paths (`graphify-out/`, `docs/`, `tools/`, etc.) and ships **arm64-v8a only** to avoid a second native ABI.

**OGG migration (deferred):** Per C11 scope decision, WAV assets were not converted in this phase. A follow-up issue should track WAV → Ogg Vorbis migration (requires an external encoder; Godot's WAV importer does not produce Vorbis). Re-run this audit after that migration or after a release (`make apk-release`) export.

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| `No export template found at .../android_source.zip` | Install 4.7.stable export templates; ensure `android_source.zip` is directly under `export_templates/4.7.stable/`. |
| `Android build template not installed` | Run `make setup-android`. Committed markers: `android/.build_version` (must read `4.7.stable`), `android/.gdignore`, `android/plugins/`. Heavy `android/build/` is gitignored and generated locally. |
| `ETC2/ASTC texture compression is required` | `project.godot` sets `textures/vram_compression/import_etc2_astc=true`; run `godot --headless --path . --import` to reimport textures. |
| `Unsupported class file major version` | Point Godot Java SDK to **JDK 17**, not JDK 21+. |
| `cannot connect to daemon at tcp:5037` | Harmless during headless export if `adb` is not running; ignore unless deploying to a device. |
| `KEYSTORE_PATH not set` / `Keystore not found` | `make apk-release` fail-closed — fill `.env` and verify the keystore file exists before retrying. |
| APK over 50 MB | See section 6; plan WAV → OGG follow-up or audit release build size. |

## Makefile targets

| Target | Purpose |
|---|---|
| `make check` | Import refresh + 60s headless boot |
| `make setup-android` | `godot --install-android-build-template` |
| `make apk-debug` | Signed debug APK → `export/syn-grid-debug.apk` |
| `make apk-release` | Signed release APK → `export/syn-grid-release.apk` (requires `.env`) |
| `make clean` | Remove `export/` |

## Pre-flight checklist (`docs/juice_manual.md` §7)

Walk before tagging any release APK:

| # | Item | Status (C11 implementation) |
|---|---|---|
| 1 | Non-LINEAR tweens | Pass (code review) |
| 2 | Synergy glow shader | Pass |
| 3 | Combat log 0.10s queue | Pass |
| 4 | Crit screen shake | Pass |
| 5 | BGM cross-fade | Pass |
| 6 | 14 SFX wired | Pass (`AudioPreviewHarness`: cache 14) |
| 7 | Damage floats | Pass |
| 8 | No glassmorphic live numbers | Pass |
| 9 | `BASE_URL` only in `ApiClient.gd` | Pass |
| 10 | No C# | Pass |
| 11 | `@export` on tunables | Pass |
| 12 | Fatal LPF sweep | Pass (`lpf_cleared=true` harness) |
| 13 | Eliminated end-game screen | Pass (C7) |
| 14 | APK under 50 MB | **Fail** (78 MB debug; OGG migration deferred) |
