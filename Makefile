# Edgy build targets. Outputs go to build/release/; nothing here installs or launches the app.
#   make app      release build, signed with your Apple Development identity if you have one,
#                 else ad-hoc (then re-grant Accessibility after every rebuild)
#   make dmg      app + drag-to-Applications disk image (unsigned)
#   make release  the signed, notarized release (needs a Developer ID; see docs/RELEASING.md)
#   make clean    remove build/release/

RELEASE_DIR := build/release
APP := $(RELEASE_DIR)/Edgy.app

.PHONY: app dmg release clean

app:
	scripts/bundle.sh --out $(APP) --sign dev-or-adhoc

dmg: app
	scripts/make-dmg.sh $(APP)

release:
	scripts/release.sh

clean:
	rm -rf $(RELEASE_DIR)
