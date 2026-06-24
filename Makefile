SHELL := /bin/sh

SCHEME ?= ScrollElevator
CONFIG ?= Release
TEAM_ID ?= 542GXYT5Z2
SIGN_IDENTITY := Developer ID Application: Kevin Tang (542GXYT5Z2)
PROJECT := ScrollElevator.xcodeproj
PROJECT_YML := project.yml

# Load version from version.env
include version.env
export MARKETING_VERSION
export BUILD_NUMBER

BUILD_SETTINGS = xcodebuild -showBuildSettings -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG)
TARGET_BUILD_DIR := $(shell $(BUILD_SETTINGS) 2>/dev/null | awk -F ' = ' '/TARGET_BUILD_DIR/ {print $$2; exit}')
WRAPPER_NAME := $(shell $(BUILD_SETTINGS) 2>/dev/null | awk -F ' = ' '/WRAPPER_NAME/ {print $$2; exit}')
APP_PATH := $(TARGET_BUILD_DIR)/$(WRAPPER_NAME)
PROCESS_NAME := $(basename $(WRAPPER_NAME))

.PHONY: gen build test install app-path clean notarize release

gen:
	xcodegen generate

build:
	@test -d $(PROJECT) || $(MAKE) gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		MARKETING_VERSION=$(MARKETING_VERSION) CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) \
		-allowProvisioningUpdates build

test:
	@test -d $(PROJECT) || $(MAKE) gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination 'platform=macOS' DEVELOPMENT_TEAM=$(TEAM_ID) test

# Clean-replace before ditto (ditto MERGES into an existing bundle — stale
# files from previous builds break the signature seal and reset TCC grants),
# then sign the exact bundle that runs, in place, with the stable Developer ID
# identity so the Accessibility grant persists across installs.
install: build
	-pkill -x "$(PROCESS_NAME)" || true
	sleep 1
	rm -rf "/Applications/$(WRAPPER_NAME)"
	/usr/bin/ditto "$(APP_PATH)" "/Applications/$(WRAPPER_NAME)"
	codesign --force --sign "$(SIGN_IDENTITY)" --options runtime --timestamp=none \
		--entitlements ScrollElevator/ScrollElevator/Resources/ScrollElevator.entitlements \
		"/Applications/$(WRAPPER_NAME)"
	codesign --verify --strict "/Applications/$(WRAPPER_NAME)"
	open "/Applications/$(WRAPPER_NAME)"

app-path:
	@echo "$(APP_PATH)"

# Build a universal, Developer-ID-signed, notarized, stapled DMG in ./release.
notarize:
	./Scripts/sign-and-notarize.sh

# Full release: validate git, notarize DMG, tag, GitHub release, open ./release
# for the Gumroad upload. Bump version.env first.
release:
	./Scripts/release.sh

clean:
	-xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean 2>/dev/null
	rm -rf ~/Library/Developer/Xcode/DerivedData/ScrollElevator-*
