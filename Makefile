# Builds Max with the Swift toolchain from Xcode Command Line Tools (no Xcode needed).
#   make          – build build.noindex/Max.app (universal)
#   make test     – run the model tests
#   make run      – build, then launch it
#   make install  – copy it to /Applications and refresh its icon and Spotlight entry
#   make dmg      – package it as build.noindex/Max-<version>.dmg
#   make release  – Developer ID signing, DMG, notarization, and stapling (see RELEASING.md)

APP_NAME      := Max
BUNDLE_ID     := jasonschulke.Max
VERSION       := 2.0.0
BUILD_NUMBER  := 2
MIN_MACOS     := 26.0
ARCHS         := arm64 x86_64
# Accessibility access is tied to the signature. An ad-hoc one (-) changes every build; the self-signed
# "Max Local Signing" certificate (Tools/make-signing-identity.sh) does not, so it is used when present.
SIGN_IDENTITY ?= $(shell security find-certificate -c "Max Local Signing" >/dev/null 2>&1 && echo "Max Local Signing" || echo -)

# Spotlight skips folders named *.noindex, so the build copy never shows up next to the installed one.
BUILD_DIR     := build.noindex
APP           := $(BUILD_DIR)/$(APP_NAME).app
INSTALLED     := /Applications/$(APP_NAME).app
LSREGISTER    := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
DMG           := $(BUILD_DIR)/$(APP_NAME)-$(VERSION).dmg
# Release signing: a "Developer ID Application: …" identity and a notarytool keychain profile.
DEVELOPER_ID  ?=
NOTARY_PROFILE ?=
SDK           := $(shell xcrun --show-sdk-path)
SOURCES       := $(shell find Max -name '*.swift' | sort)
MODEL_SOURCES := $(sort $(wildcard Max/Models/*.swift))
TEST_SOURCES  := $(sort $(wildcard Tests/*.swift))
INFO_PLIST    := Max/Resources/Info.plist
ICON          := Max/Resources/Max.icns

SWIFT_FLAGS   := -swift-version 6 -default-isolation MainActor -parse-as-library -O -sdk $(SDK)
BINARIES      := $(foreach arch,$(ARCHS),$(BUILD_DIR)/$(APP_NAME)-$(arch))

.PHONY: all build test run install dmg release clean

all: build

build: $(APP)/Contents/MacOS/$(APP_NAME)

$(BUILD_DIR)/$(APP_NAME)-%: $(SOURCES) Makefile
	@mkdir -p $(BUILD_DIR)
	swiftc $(SWIFT_FLAGS) -target $*-apple-macos$(MIN_MACOS) -o $@ $(SOURCES)

$(APP)/Contents/MacOS/$(APP_NAME): $(BINARIES) $(INFO_PLIST) $(ICON) Makefile
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	lipo -create -output $@ $(BINARIES)
	cp $(ICON) $(APP)/Contents/Resources/
	sed -e 's/$$(EXECUTABLE_NAME)/$(APP_NAME)/g' \
	    -e 's/$$(PRODUCT_NAME)/$(APP_NAME)/g' \
	    -e 's/$$(PRODUCT_BUNDLE_IDENTIFIER)/$(BUNDLE_ID)/g' \
	    -e 's/$$(MARKETING_VERSION)/$(VERSION)/g' \
	    -e 's/$$(CURRENT_PROJECT_VERSION)/$(BUILD_NUMBER)/g' \
	    -e 's/$$(MACOSX_DEPLOYMENT_TARGET)/$(MIN_MACOS)/g' \
	    $(INFO_PLIST) > $(APP)/Contents/Info.plist
	printf 'APPL????' > $(APP)/Contents/PkgInfo
	codesign --force --sign "$(SIGN_IDENTITY)" $(APP)
	@echo "Built $(APP)"

test: $(BUILD_DIR)/$(APP_NAME)Tests
	$(BUILD_DIR)/$(APP_NAME)Tests

$(BUILD_DIR)/$(APP_NAME)Tests: $(MODEL_SOURCES) $(TEST_SOURCES) Makefile
	@mkdir -p $(BUILD_DIR)
	swiftc -swift-version 6 -sdk $(SDK) -target arm64-apple-macos$(MIN_MACOS) -o $@ $(MODEL_SOURCES) $(TEST_SOURCES)

run: build
	open $(APP)

install: build
	rm -rf $(INSTALLED)
	cp -R $(APP) $(INSTALLED)
	touch $(INSTALLED)
	$(LSREGISTER) -f $(INSTALLED)
	mdimport $(INSTALLED)

dmg: build
	rm -rf $(BUILD_DIR)/dmg $(DMG)
	mkdir -p $(BUILD_DIR)/dmg
	cp -R $(APP) $(BUILD_DIR)/dmg/
	ln -s /Applications $(BUILD_DIR)/dmg/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(BUILD_DIR)/dmg -fs HFS+ -format UDZO -ov $(DMG)
	rm -rf $(BUILD_DIR)/dmg
	@echo "Built $(DMG)"

release:
	@test -n "$(DEVELOPER_ID)" || { echo 'Set DEVELOPER_ID="Developer ID Application: …" (see RELEASING.md)'; exit 1; }
	@test -n "$(NOTARY_PROFILE)" || { echo 'Set NOTARY_PROFILE to a notarytool keychain profile (see RELEASING.md)'; exit 1; }
	$(MAKE) build
	# Notarization requires the hardened runtime and a secure timestamp.
	codesign --force --options runtime --timestamp --sign "$(DEVELOPER_ID)" $(APP)
	$(MAKE) dmg
	codesign --force --timestamp --sign "$(DEVELOPER_ID)" $(DMG)
	xcrun notarytool submit $(DMG) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(DMG)
	xcrun stapler validate $(DMG)
	@echo "Released $(DMG)"

clean:
	rm -rf $(BUILD_DIR)
