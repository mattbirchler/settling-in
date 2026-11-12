PROJECT = Settle.xcodeproj
SCHEME = Settle
DERIVED = build
CORE = Packages/SettleCore
XCODEBUILD = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED) -skipPackagePluginValidation -skipMacroValidation
APP = $(DERIVED)/Build/Products/Debug/Settling In.app
APP_NAME = Settling In

.PHONY: project build test run install dmg notarize clean

project:
	xcodegen generate --quiet

# Builds the app. Output is filtered to errors, app warnings and the result line.
build: project
	@mkdir -p $(DERIVED)
	@$(XCODEBUILD) -configuration Debug -destination 'platform=macOS' build > $(DERIVED)/last-build.log 2>&1; status=$$?; \
	grep -E "error:|warning:.*/(App|Packages)/|BUILD (SUCCEEDED|FAILED)" $(DERIVED)/last-build.log | sort -u; \
	exit $$status

# Core tests run with swift test. Usage: make test   or   make test ONLY=PowerLogTests
test:
	@mkdir -p $(DERIVED)
	@cd $(CORE) && swift test $(if $(ONLY),--filter $(ONLY),) > ../../$(DERIVED)/last-test.log 2>&1; status=$$?; \
	grep -E "error:|✘|Test run with|passed after|failed after" ../../$(DERIVED)/last-test.log | tail -40; exit $$status

# Builds, quits any running copy and launches the new one.
run: build
	-@pkill -x "$(APP_NAME)"; pkill -x Settle; sleep 0.5
	open "$(APP)"

# Release build copied to /Applications, replacing any older copy, then launched.
install: project
	@mkdir -p $(DERIVED)
	@$(XCODEBUILD) -configuration Release -destination 'platform=macOS' build > $(DERIVED)/last-release.log 2>&1; status=$$?; \
	grep -E "error:|BUILD (SUCCEEDED|FAILED)" $(DERIVED)/last-release.log | sort -u; \
	exit $$status
	-@pkill -x "$(APP_NAME)"; pkill -x Settle; sleep 0.5
	rm -rf "/Applications/$(APP_NAME).app" /Applications/Settle.app
	cp -R "$(DERIVED)/Build/Products/Release/$(APP_NAME).app" /Applications/
	open "/Applications/$(APP_NAME).app"

# The install disk image, unsigned, from the copy in /Applications, to check
# how it looks: build/Settling-In.dmg. `make notarize` makes the signed one.
dmg:
	@scripts/make-dmg.sh "/Applications/$(APP_NAME).app" $(DERIVED)/Settling-In.dmg

# A Release build signed with Developer ID and notarized by Apple, as a disk
# image and a zip in build/notarized/. Needs fastlane/.env.
notarize:
	@scripts/notarize.sh

clean:
	rm -rf $(DERIVED)
