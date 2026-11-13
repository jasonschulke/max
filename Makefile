# Builds Max with the Swift toolchain from Xcode Command Line Tools (no Xcode needed).
#   make          – build Max.app (universal, ad-hoc signed)
#   make test     – run the model tests
#   make run      – build, then launch Max.app
#   make install  – copy Max.app to /Applications

APP_NAME      := Max
BUNDLE_ID     := jasonschulke.Max
VERSION       := 2.0.0
BUILD_NUMBER  := 2
MIN_MACOS     := 26.0
ARCHS         := arm64 x86_64
# Accessibility access is tied to the signature. An ad-hoc one (-) changes every build; the self-signed
# "Max Local Signing" certificate (Tools/make-signing-identity.sh) does not, so it is used when present.
SIGN_IDENTITY ?= $(shell security find-certificate -c "Max Local Signing" >/dev/null 2>&1 && echo "Max Local Signing" || echo -)

APP           := $(APP_NAME).app
BUILD_DIR     := build
SDK           := $(shell xcrun --show-sdk-path)
SOURCES       := $(shell find Max -name '*.swift' | sort)
MODEL_SOURCES := $(sort $(wildcard Max/Models/*.swift))
TEST_SOURCES  := $(sort $(wildcard Tests/*.swift))
INFO_PLIST    := Max/Resources/Info.plist
ICON          := Max/Resources/Max.icns

SWIFT_FLAGS   := -swift-version 6 -default-isolation MainActor -parse-as-library -O -sdk $(SDK)
BINARIES      := $(foreach arch,$(ARCHS),$(BUILD_DIR)/$(APP_NAME)-$(arch))

.PHONY: all build test run install clean

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
	rm -rf /Applications/$(APP)
	cp -R $(APP) /Applications/$(APP)

clean:
	rm -rf $(BUILD_DIR) $(APP)
