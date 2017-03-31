default: test

TEST_PROJECT = GRDB.xcodeproj
TEST_ACTIONS = clean build build-for-testing test-without-building
IOS_SIMULATOR_DESTINATION_HIGH_TARGET = "platform=iOS Simulator,name=iPhone 7,OS=10.3"
IOS_SIMULATOR_DESTINATION_LOW_TARGET = "platform=iOS Simulator,name=iPhone 4s,OS=8.1"
POD := $(shell command -v pod)
CARTHAGE := $(shell command -v carthage)

test: test_build test_install

test_build: test_build_GRDB test_build_GRDBCustom test_build_GRDBCipher

test_build_GRDB: test_build_GRDBOSX test_build_GRDBiOS

test_build_GRDBCustom: test_build_GRDBCustomSQLiteOSX test_build_GRDBCustomSQLiteiOS

test_build_GRDBCipher: test_build_GRDBCipherOSX test_build_GRDBCipheriOS

test_build_GRDBOSX:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBOSX \
	  $(TEST_ACTIONS)

test_build_GRDBiOS: test_build_GRDBiOS_highTarget test_build_GRDBiOS_lowTarget

test_build_GRDBiOS_highTarget:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBiOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_HIGH_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBiOS_lowTarget:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBiOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_LOW_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBCustomSQLiteOSX:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCustomSQLiteOSX \
	  $(TEST_ACTIONS)

test_build_GRDBCustomSQLiteiOS: test_build_GRDBCustomSQLiteiOS_highTarget test_build_GRDBCustomSQLiteiOS_lowTarget

test_build_GRDBCustomSQLiteiOS_highTarget:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_HIGH_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBCustomSQLiteiOS_lowTarget:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_LOW_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBCipherOSX:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCipherOSX \
	  $(TEST_ACTIONS)

test_build_GRDBCipheriOS: test_build_GRDBCipheriOS_highTarget test_build_GRDBCipheriOS_lowTarget

test_build_GRDBCipheriOS_highTarget:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCipheriOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_HIGH_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBCipheriOS_lowTarget:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCipheriOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_LOW_TARGET) \
	  $(TEST_ACTIONS)

test_install: test_installManual test_CocoaPodsLint test_CarthageBuild

test_installManual:
	xcodebuild \
	  -project DemoApps/GRDBDemoiOS/GRDBDemoiOS.xcodeproj \
	  -scheme GRDBDemoiOS \
	  -configuration Release \
	  -destination $(IOS_SIMULATOR_DESTINATION_HIGH_TARGET) \
	  clean build

test_CocoaPodsLint:
ifdef POD
	$(POD) lib lint --allow-warnings
else
	@echo CocoaPods must be installed for test_CocoaPodsLint
	@exit 1
endif

test_CarthageBuild:
ifdef CARTHAGE
	rm -rf Carthage
	$(CARTHAGE) build --no-skip-current
else
	@echo Carthage must be installed for test_CocoaPodsLint
	@exit 1
endif

.PHONY: doc
doc:
	jazzy \
	  --clean \
	  --author 'Gwendal Roué' \
	  --author_url https://github.com/groue \
	  --github_url https://github.com/groue/GRDB.swift \
	  --github-file-prefix https://github.com/groue/GRDB.swift/tree/v0.102.0 \
	  --module-version 0.102.0 \
	  --module GRDB \
	  --root-url http://groue.github.io/GRDB.swift/docs/0.102.0/ \
	  --output Documentation/Reference \
	  --podspec GRDB.swift.podspec
