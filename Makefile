-include .env
export

GODOT ?= godot
EXPORT_DIR := export
BOOT_CHECK_SECONDS := 60
PRESET := export_presets.cfg

.PHONY: check setup-android apk-debug apk-release clean

check:
	$(GODOT) --headless --path . --import
	$(GODOT) --headless --path . --quit-after $(BOOT_CHECK_SECONDS)

setup-android:
	$(GODOT) --headless --path . --install-android-build-template

apk-debug: check
	@test -f "$(PRESET)" || (echo "Missing $(PRESET) — cp export_presets.cfg.example $(PRESET)"; exit 1)
	@if [ -n "$(ANDROID_DEBUG_KEYSTORE_PATH)" ]; then \
		test -f "$(ANDROID_DEBUG_KEYSTORE_PATH)" || (echo "Debug keystore not found at $(ANDROID_DEBUG_KEYSTORE_PATH)"; exit 1); \
		test -n "$(ANDROID_DEBUG_KEYSTORE_USER)" || (echo "ANDROID_DEBUG_KEYSTORE_USER not set — check .env"; exit 1); \
		test -n "$(ANDROID_DEBUG_KEYSTORE_PASS)" || (echo "ANDROID_DEBUG_KEYSTORE_PASS not set — check .env"; exit 1); \
		python3 tools/sync_export_keystore.py --debug; \
	fi
	@mkdir -p $(EXPORT_DIR)
	$(GODOT) --headless --export-debug "Android" $(EXPORT_DIR)/syn-grid-debug.apk

apk-release: check
	@test -f "$(PRESET)" || (echo "Missing $(PRESET) — cp export_presets.cfg.example $(PRESET)"; exit 1)
	@test -n "$(KEYSTORE_PATH)" || (echo "KEYSTORE_PATH not set — check .env (see .env.example)"; exit 1)
	@test -f "$(KEYSTORE_PATH)" || (echo "Keystore not found at $(KEYSTORE_PATH)"; exit 1)
	@test -n "$(KEYSTORE_PASS)" || (echo "KEYSTORE_PASS not set — check .env"; exit 1)
	@test -n "$(KEYSTORE_ALIAS)" || (echo "KEYSTORE_ALIAS not set — check .env"; exit 1)
	@python3 tools/sync_export_keystore.py --release
	@mkdir -p $(EXPORT_DIR)
	$(GODOT) --headless --export-release "Android" $(EXPORT_DIR)/syn-grid-release.apk

clean:
	rm -rf $(EXPORT_DIR)
