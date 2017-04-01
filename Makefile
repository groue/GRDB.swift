# Requirements
# ============
#
# CocoaPods ~> 1.2.0 - https://cocoapods.org
# Carthage ~> 0.20.1 - https://github.com/carthage/carthage
# Jazzy ~> 0.7.4 - https://github.com/realm/jazzy

POD := $(shell command -v pod)
CARTHAGE := $(shell command -v carthage)
JAZZY := $(shell command -v jazzy)


# Targets
# =======
#
# make: run all tests
# make test: run all tests
# make doc: generates documentation

default: test


# Tests
# =====

# xcodebuild actions to run test targets
TEST_ACTIONS = clean build build-for-testing test-without-building

# xcodebuild destination to run tests on iOS 8.1 (requires a pre-installed simulator)
MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 4s,OS=8.1"

# xcodebuild destination to run tests on latest iOS (Xcode 8.3)
MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 7,OS=10.3"

# xcodebuild destination to run tests on latest iOS (Xcode 8.1)
# MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 6s,OS=10.1"

# We test framework test suites, and if GRBD can be installed in an application:
test: test_framework test_install

test_framework: test_framework_GRDB test_framework_GRDBCustom test_framework_GRDBCipher
test_framework_GRDB: test_framework_GRDBOSX test_framework_GRDBWatchOS test_framework_GRDBiOS
test_framework_GRDBCustom: test_framework_GRDBCustomSQLiteOSX test_framework_GRDBCustomSQLiteiOS
test_framework_GRDBCipher: test_framework_GRDBCipherOSX test_framework_GRDBCipheriOS
test_install: test_install_manual test_install_GRDBCipher test_CocoaPodsLint test_CarthageBuild

test_framework_GRDBOSX:
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBOSX \
	  $(TEST_ACTIONS)

test_framework_GRDBWatchOS:
	# XCTest is not supported for watchOS: we only make sure that the framework builds.
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBWatchOS \
	  clean build

test_framework_GRDBiOS: test_framework_GRDBiOS_maxTarget test_framework_GRDBiOS_minTarget

test_framework_GRDBiOS_maxTarget:
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  $(TEST_ACTIONS)

test_framework_GRDBiOS_minTarget:
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBiOS \
	  -destination $(MIN_IOS_DESTINATION) \
	  $(TEST_ACTIONS)

test_framework_GRDBCustomSQLiteOSX: SQLiteCustom
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCustomSQLiteOSX \
	  $(TEST_ACTIONS)

test_framework_GRDBCustomSQLiteiOS: test_framework_GRDBCustomSQLiteiOS_maxTarget test_framework_GRDBCustomSQLiteiOS_minTarget

test_framework_GRDBCustomSQLiteiOS_maxTarget: SQLiteCustom
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  $(TEST_ACTIONS)

test_framework_GRDBCustomSQLiteiOS_minTarget: SQLiteCustom
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(MIN_IOS_DESTINATION) \
	  $(TEST_ACTIONS)

test_framework_GRDBCipherOSX: SQLCipher
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCipherOSX \
	  $(TEST_ACTIONS)

test_framework_GRDBCipheriOS: test_framework_GRDBCipheriOS_maxTarget test_framework_GRDBCipheriOS_minTarget

test_framework_GRDBCipheriOS_maxTarget: SQLCipher
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCipheriOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  $(TEST_ACTIONS)

test_framework_GRDBCipheriOS_minTarget: SQLCipher
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCipheriOS \
	  -destination $(MIN_IOS_DESTINATION) \
	  $(TEST_ACTIONS)

test_install_manual:
	xcodebuild \
	  -project DemoApps/GRDBDemoiOS/GRDBDemoiOS.xcodeproj \
	  -scheme GRDBDemoiOS \
	  -configuration Release \
	  -destination $(MAX_IOS_DESTINATION) \
	  clean build

test_install_GRDBCipher: SQLCipher
	xcodebuild \
	  -project Tests/GRDBCipher/GRDBiOS/GRDBiOS.xcodeproj \
	  -scheme GRDBiOS \
	  -configuration Release \
	  -destination $(MAX_IOS_DESTINATION) \
	  clean build

test_CocoaPodsLint:
ifdef POD
	$(POD) lib lint --allow-warnings
else
	@echo CocoaPods must be installed for test_CocoaPodsLint
	@exit 1
endif

test_CarthageBuild: SQLiteCustom SQLCipher
# Disabled because https://github.com/Carthage/Carthage/issues/1867
# ifdef CARTHAGE
# 	rm -rf Carthage
# 	$(CARTHAGE) build --no-skip-current
# else
# 	@echo Carthage must be installed for test_CarthageBuild
# 	@exit 1
# endif

# Target that setups SQLite custom builds with SQLITE_ENABLE_PREUPDATE_HOOK and
# SQLITE_ENABLE_FTS5 extra compilation options.
SQLiteCustom: SQLiteCustom/src/sqlite3.h
	echo '/* Makefile generated */' > SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '#define SQLITE_ENABLE_PREUPDATE_HOOK' >> SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '#define SQLITE_ENABLE_FTS5' >> SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '// Makefile generated' > SQLiteCustom/GRDBCustomSQLite-USER.xcconfig
	echo 'CUSTOM_OTHER_SWIFT_FLAGS = -D SQLITE_ENABLE_PREUPDATE_HOOK -D SQLITE_ENABLE_FTS5' >> SQLiteCustom/GRDBCustomSQLite-USER.xcconfig
	echo '// Makefile generated' > SQLiteCustom/src/SQLiteLib-USER.xcconfig
	echo 'CUSTOM_SQLLIBRARY_CFLAGS = -DSQLITE_ENABLE_PREUPDATE_HOOK -DSQLITE_ENABLE_FTS5' >> SQLiteCustom/src/SQLiteLib-USER.xcconfig

# Makes sure the SQLiteCustom/src submodule has been downloaded
SQLiteCustom/src/sqlite3.h:
	git submodule update --init SQLiteCustom/src

# Target that setups SQLCipher
SQLCipher: SQLCipher/src/sqlite3.h

# Makes sure the SQLCipher/src submodule has been downloaded
SQLCipher/src/sqlite3.h:
	git submodule update --init SQLCipher/src


# Documentation
# =============

doc:
ifdef JAZZY
	$(JAZZY) \
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
else
	@echo Jazzy must be installed for doc
	@exit 1
endif

.PHONY: doc test SQLCipher SQLiteCustom
