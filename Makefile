SHELL := /bin/sh

SCHEME ?= ScrollElevator
CONFIG ?= Release
TEAM_ID ?= 542GXYT5Z2
SIGN_IDENTITY := Developer ID Application: Kevin Tang (542GXYT5Z2)
PROJECT := ScrollElevator.xcodeproj
PROJECT_YML := project.yml

BUILD_SETTINGS = xcodebuild -showBuildSettings -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG)
TARGET_BUILD_DIR := $(shell $(BUILD_SETTINGS) 2>/dev/null | awk -F ' = ' '/TARGET_BUILD_DIR/ {print $$2; exit}')
WRAPPER_NAME := $(shell $(BUILD_SETTINGS) 2>/dev/null | awk -F ' = ' '/WRAPPER_NAME/ {print $$2; exit}')
APP_PATH := $(TARGET_BUILD_DIR)/$(WRAPPER_NAME)
PROCESS_NAME := $(basename $(WRAPPER_NAME))

.PHONY: gen build install app-path clean

gen:
	xcodegen generate

build:
	@test -d $(PROJECT) || $(MAKE) gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		DEVELOPMENT_TEAM=$(TEAM_ID) -allowProvisioningUpdates build

install: build
	-pkill -x "$(PROCESS_NAME)" || true
	sleep 1
	codesign --force --sign "$(SIGN_IDENTITY)" --options runtime --timestamp=none \
		--entitlements ScrollElevator/ScrollElevator/Resources/ScrollElevator.entitlements "$(APP_PATH)"
	/usr/bin/ditto "$(APP_PATH)" "/Applications/$(WRAPPER_NAME)"
	open "/Applications/$(WRAPPER_NAME)"

app-path:
	@echo "$(APP_PATH)"

clean:
	-xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean 2>/dev/null
	rm -rf ~/Library/Developer/Xcode/DerivedData/ScrollElevator-*
