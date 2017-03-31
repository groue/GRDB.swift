default: test

BUILD_TOOL = xcodebuild
TEST_PROJECT = GRDB.xcodeproj
TEST_ACTIONS = clean build build-for-testing test-without-building
IOS_SIMULATOR_DESTINATION_LOW_TARGET = "platform=iOS Simulator,name=iPhone 4s,OS=8.1"

# Xcode 8.3
IOS_SIMULATOR_DESTINATION_HIGH_TARGET = "platform=iOS Simulator,name=iPhone 7,OS=10.3"

# Xcode 8.1
# IOS_SIMULATOR_DESTINATION_HIGH_TARGET = "platform=iOS Simulator,name=iPhone 6s,OS=10.1"

POD := $(shell command -v pod)
CARTHAGE := $(shell command -v carthage)

test: test_build test_install

test_build: test_build_GRDB test_build_GRDBCustom test_build_GRDBCipher

test_build_GRDB: test_build_GRDBOSX test_build_GRDBiOS

test_build_GRDBCustom: test_build_GRDBCustomSQLiteOSX test_build_GRDBCustomSQLiteiOS

test_build_GRDBCipher: test_build_GRDBCipherOSX test_build_GRDBCipheriOS

test_build_GRDBOSX:
	$(BUILD_TOOL) \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBOSX \
	  $(TEST_ACTIONS)

test_build_GRDBiOS: test_build_GRDBiOS_highTarget test_build_GRDBiOS_lowTarget

test_build_GRDBiOS_highTarget:
	$(BUILD_TOOL) \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBiOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_HIGH_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBiOS_lowTarget:
	$(BUILD_TOOL) \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBiOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_LOW_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBCustomSQLiteOSX: SQLiteCustom
	$(BUILD_TOOL) \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCustomSQLiteOSX \
	  $(TEST_ACTIONS)

test_build_GRDBCustomSQLiteiOS: test_build_GRDBCustomSQLiteiOS_highTarget test_build_GRDBCustomSQLiteiOS_lowTarget

test_build_GRDBCustomSQLiteiOS_highTarget: SQLiteCustom
	$(BUILD_TOOL) \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_HIGH_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBCustomSQLiteiOS_lowTarget: SQLiteCustom
	$(BUILD_TOOL) \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_LOW_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBCipherOSX: SQLCipher
	$(BUILD_TOOL) \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCipherOSX \
	  $(TEST_ACTIONS)

test_build_GRDBCipheriOS: test_build_GRDBCipheriOS_highTarget test_build_GRDBCipheriOS_lowTarget

test_build_GRDBCipheriOS_highTarget: SQLCipher
	$(BUILD_TOOL) \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCipheriOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_HIGH_TARGET) \
	  $(TEST_ACTIONS)

test_build_GRDBCipheriOS_lowTarget: SQLCipher
	$(BUILD_TOOL) \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCipheriOS \
	  -destination $(IOS_SIMULATOR_DESTINATION_LOW_TARGET) \
	  $(TEST_ACTIONS)

test_install: test_installManual test_installGRDBCipher test_CocoaPodsLint test_CarthageBuild

test_installManual:
	$(BUILD_TOOL) \
	  -project DemoApps/GRDBDemoiOS/GRDBDemoiOS.xcodeproj \
	  -scheme GRDBDemoiOS \
	  -configuration Release \
	  -destination $(IOS_SIMULATOR_DESTINATION_HIGH_TARGET) \
	  clean build

test_installGRDBCipher: SQLCipher
	$(BUILD_TOOL) \
	  -project Tests/GRDBCipher/GRDBiOS/GRDBiOS.xcodeproj \
	  -scheme GRDBiOS \
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

test_CarthageBuild: SQLiteCustom SQLCipher
ifdef CARTHAGE
	rm -rf Carthage
	$(CARTHAGE) build --no-skip-current
else
	@echo Carthage must be installed for test_CocoaPodsLint
	@exit 1
endif

SQLiteCustom: SQLiteCustom/src/sqlite3.h
	echo '/* Makefile generated */' > SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '#define SQLITE_ENABLE_PREUPDATE_HOOK' >> SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '#define SQLITE_ENABLE_FTS5' >> SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '// Makefile generated' > SQLiteCustom/GRDBCustomSQLite-USER.xcconfig
	echo 'CUSTOM_OTHER_SWIFT_FLAGS = -D SQLITE_ENABLE_PREUPDATE_HOOK -D SQLITE_ENABLE_FTS5' >> SQLiteCustom/GRDBCustomSQLite-USER.xcconfig
	echo '// Makefile generated' > SQLiteCustom/src/SQLiteLib-USER.xcconfig
	echo 'CUSTOM_SQLLIBRARY_CFLAGS = -DSQLITE_ENABLE_PREUPDATE_HOOK -DSQLITE_ENABLE_FTS5' >> SQLiteCustom/src/SQLiteLib-USER.xcconfig

SQLiteCustom/src/sqlite3.h:
	git submodule update --init SQLiteCustom/src

SQLCipher: SQLCipher/src/sqlite3.h

SQLCipher/src/sqlite3.h:
	git submodule update --init SQLCipher/src

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

.PHONY: doc test SQLCipher SQLiteCustom
