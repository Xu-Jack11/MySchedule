.PHONY: generate build archive ipa clean

PROJECT = MySchedule.xcodeproj
SCHEME = MySchedule
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/MySchedule.xcarchive
IPA_DIR = $(BUILD_DIR)/ipa

generate:
	xcodegen generate

build: generate
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'generic/platform=iOS Simulator' \
		-configuration Debug \
		CODE_SIGNING_ALLOWED=NO

archive: generate
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-archivePath $(ARCHIVE_PATH) \
		-destination 'generic/platform=iOS' \
		-configuration Release \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY=""

ipa: archive
	mkdir -p $(IPA_DIR)
	cd $(ARCHIVE_PATH)/Products/Applications && \
		mkdir -p Payload && \
		mv MySchedule.app Payload/ && \
		zip -r ../../../../$(IPA_DIR)/MySchedule.ipa Payload
	@echo "IPA exported to $(IPA_DIR)/MySchedule.ipa"

clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null || true
