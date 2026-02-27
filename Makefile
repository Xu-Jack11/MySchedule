.PHONY: generate build install release bump-patch bump-minor bump-major clean

PROJECT    = MySchedule.xcodeproj
SCHEME     = MySchedule
DEVICE_ID  = 00008120-00020C3601F8201E
TEAM_ID    = 9B772P8622
BUILD_DIR  = build
APP_PATH   = $(HOME)/Library/Developer/Xcode/DerivedData/MySchedule-dvwugqjgmjvznvcyltwaxwvrsaqj/Build/Products/Debug-iphoneos/MySchedule.app

# 自动从 git 提交数计算 build number
BUILD_NUMBER := $(shell git rev-list --count HEAD)
VERSION      := $(shell python3 -c "import re,sys; s=open('project.yml').read(); m=re.search(r'MARKETING_VERSION: \"([^\"]+)\"', s); print(m.group(1) if m else '1.0.0')")

generate:
	xcodegen generate

build: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS,id=$(DEVICE_ID)' \
		-allowProvisioningUpdates \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) \
		build

install: build
	xcrun devicectl device install app \
		--device $(DEVICE_ID) \
		"$(APP_PATH)"
	@echo "✅ Installed v$(VERSION) (build $(BUILD_NUMBER))"

release: install
	git add -A
	git commit -m "chore(release): bump version to $(VERSION) (build $(BUILD_NUMBER))"
	git tag -a "v$(VERSION)" -m "Release v$(VERSION) (build $(BUILD_NUMBER))"
	git push origin main --tags
	@echo "🚀 Released v$(VERSION) (build $(BUILD_NUMBER))"

# 版本号管理
bump-patch:
	@python3 -c "\
import re; p=open('project.yml'); s=p.read(); p.close(); \
m=re.search(r'MARKETING_VERSION: \"(\d+)\.(\d+)\.(\d+)\"', s); \
v='%s.%s.%d'%(m.group(1),m.group(2),int(m.group(3))+1); \
open('project.yml','w').write(re.sub(r'MARKETING_VERSION: \"[^\"]+\"','MARKETING_VERSION: \"'+v+'\"',s)); \
print('Bumped to',v)"

bump-minor:
	@python3 -c "\
import re; p=open('project.yml'); s=p.read(); p.close(); \
m=re.search(r'MARKETING_VERSION: \"(\d+)\.(\d+)\.(\d+)\"', s); \
v='%s.%d.0'%(m.group(1),int(m.group(2))+1); \
open('project.yml','w').write(re.sub(r'MARKETING_VERSION: \"[^\"]+\"','MARKETING_VERSION: \"'+v+'\"',s)); \
print('Bumped to',v)"

bump-major:
	@python3 -c "\
import re; p=open('project.yml'); s=p.read(); p.close(); \
m=re.search(r'MARKETING_VERSION: \"(\d+)\.(\d+)\.(\d+)\"', s); \
v='%d.0.0'%(int(m.group(1))+1,); \
open('project.yml','w').write(re.sub(r'MARKETING_VERSION: \"[^\"]+\"','MARKETING_VERSION: \"'+v+'\"',s)); \
print('Bumped to',v)"

clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null || true
