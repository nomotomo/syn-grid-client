-include .env
export

GODOT ?= godot
EXPORT_DIR := export
BOOT_CHECK_SECONDS := 60

.PHONY: check setup-android apk-debug apk-release clean

check:
	$(GODOT) --headless --path . --import
	$(GODOT) --headless --path . --quit-after $(BOOT_CHECK_SECONDS)

setup-android:
	$(GODOT) --headless --path . --install-android-build-template

apk-debug: check
	@mkdir -p $(EXPORT_DIR)
	$(GODOT) --headless --export-debug "Android" $(EXPORT_DIR)/syn-grid-debug.apk

apk-release: check
	@test -n "$(KEYSTORE_PATH)" || (echo "KEYSTORE_PATH not set - check .env (see .env.example)"; exit 1)
	@test -f "$(KEYSTORE_PATH)" || (echo "Keystore not found at $(KEYSTORE_PATH)"; exit 1)
	@test -n "$(KEYSTORE_PASS)" || (echo "KEYSTORE_PASS not set - check .env"; exit 1)
	@test -n "$(KEYSTORE_ALIAS)" || (echo "KEYSTORE_ALIAS not set - check .env"; exit 1)
	@mkdir -p $(EXPORT_DIR)
	$(GODOT) --headless --export-release "Android" $(EXPORT_DIR)/syn-grid-release.apk

clean:
	rm -rf $(EXPORT_DIR)
