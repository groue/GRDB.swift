# Rules
# =====
#
# make test - Run all tests but performance tests
# make test_performance - Run performance tests
# make documentation - Generate jazzy documentation
# make clean - Remove build artifacts
# make distclean - Restore repository to a pristine state

default: test


# Requirements
# ============
#
# Xcode >= 9.0, with iOS8.1 Simulator installed
# CocoaPods ~> 1.6.0 - https://cocoapods.org
# Jazzy ~> 0.7.4 - https://github.com/realm/jazzy

GIT := $(shell command -v git)
JAZZY := $(shell command -v jazzy)
POD := $(shell command -v pod)
XCRUN := $(shell command -v xcrun)
XCODEBUILD := set -o pipefail && $(shell command -v xcodebuild)

# Xcode Version Information
XCODEVERSION_FULL := $(word 2, $(shell xcodebuild -version))
XCODEVERSION_MAJOR := $(shell xcodebuild -version 2>&1 | grep Xcode | cut -d' ' -f2 | cut -d'.' -f1)
XCODEVERSION_MINOR := $(shell xcodebuild -version 2>&1 | grep Xcode | cut -d' ' -f2 | cut -d'.' -f2)
XCODEVERSION_PATCH := $(shell xcodebuild -version 2>&1 | grep Xcode | cut -d' ' -f2 | cut -d'.' -f3)

# The Xcode Version, containing only the "MAJOR.MINOR" (ex. "8.3" for Xcode 8.3, 8.3.1, etc.)
XCODEVERSION := $(XCODEVERSION_MAJOR).$(XCODEVERSION_MINOR)

# Used to determine if xcpretty is available
XCPRETTY_PATH := $(shell command -v xcpretty 2> /dev/null)

# Avoid the "No output has been received in the last 10m0s" error on Travis:
COCOAPODS_EXTRA_TIME =
ifeq ($(TRAVIS),true)
  COCOAPODS_EXTRA_TIME = --verbose
endif


# Tests
# =====

# xcodebuild actions to run test targets
TEST_ACTIONS = clean build build-for-testing test-without-building

# When adding support for an Xcode version, look for available devices with `instruments -s devices`
ifeq ($(XCODEVERSION),11.3)
  MAX_SWIFT_VERSION = 5.1
  MIN_SWIFT_VERSION = 4.2
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 11,OS=13.3"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5,OS=10.3.1"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=13.3"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.2"
else ifeq ($(XCODEVERSION),11.2)
  MAX_SWIFT_VERSION = 5.1
  MIN_SWIFT_VERSION = 4.2
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 11,OS=13.2.2"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5,OS=10.3.1"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=13.2"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.2"
else ifeq ($(XCODEVERSION),11.1)
  MAX_SWIFT_VERSION = 5.1
  MIN_SWIFT_VERSION = 4.2
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 11,OS=13.1"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5,OS=10.3.1"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=13.0"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.2"
else ifeq ($(XCODEVERSION),11.0)
  MAX_SWIFT_VERSION = 5.1
  MIN_SWIFT_VERSION = 4.2
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 11,OS=13.0"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5,OS=10.3.1"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=13.0"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.2"
else ifeq ($(XCODEVERSION),10.3)
  MAX_SWIFT_VERSION = 5
  MIN_SWIFT_VERSION = 4.2
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone X,OS=12.4"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5,OS=10.3.1"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=12.4"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.2"
else ifeq ($(XCODEVERSION),10.2)
  MAX_SWIFT_VERSION = 5
  MIN_SWIFT_VERSION = 4.2
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone X,OS=12.2"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 4s,OS=9.0"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=12.2"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.0"
else ifeq ($(XCODEVERSION),10.1)
  MAX_SWIFT_VERSION = 4.2
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone X,OS=12.1"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 4s,OS=9.0"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=12.1"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.0"
else ifeq ($(XCODEVERSION),10.0)
  MAX_SWIFT_VERSION = 4.2
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=12.0"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 4s,OS=9.0"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=12.0"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.0"
else
  # Swift 4.1 required: Xcode < 9.3 is not supported
endif

# If xcpretty is available, use it for xcodebuild output
XCPRETTY = 
ifdef XCPRETTY_PATH
  XCPRETTY = | xcpretty -c
  
  # On Travis-CI, use xcpretty-travis-formatter
  ifeq ($(TRAVIS),true)
    XCPRETTY += -f `xcpretty-travis-formatter`
  endif
endif

ifdef TOOLCHAIN
  # If TOOLCHAIN is specified, add xcodebuild parameter
  XCODEBUILD += -toolchain $(TOOLCHAIN)
  
  # If TOOLCHAIN is specified, get the location of the toolchain’s SWIFT
  TOOLCHAINSWIFT = $(shell $(XCRUN) --toolchain '$(TOOLCHAIN)' --find swift 2> /dev/null)
  ifdef TOOLCHAINSWIFT
    # Update the SWIFT path to the toolchain’s SWIFT
    SWIFT = $(TOOLCHAINSWIFT)
  else
    @echo Cannot find `swift` for specified toolchain.
    @exit 1
  endif
else
  # If TOOLCHAIN is not specified, use standard Swift
  SWIFT = $(shell $(XCRUN) --find swift 2> /dev/null)
endif

# We test framework test suites, and if GRBD can be installed in an application:
test: test_framework test_install

test_framework: test_framework_darwin
test_framework_darwin: test_framework_GRDB test_framework_GRDBCustom test_framework_SQLCipher test_SPM
test_framework_GRDB: test_framework_GRDBOSX test_framework_GRDBWatchOS test_framework_GRDBiOS test_framework_GRDBtvOS
test_framework_GRDBCustom: test_framework_GRDBCustomSQLiteOSX test_framework_GRDBCustomSQLiteiOS
test_framework_SQLCipher: test_framework_SQLCipher3 test_framework_SQLCipher4
test_install: test_install_manual test_install_SPM test_install_customSQLite test_install_GRDB_CocoaPods test_CocoaPodsLint
test_CocoaPodsLint: test_CocoaPodsLint_GRDB

test_framework_GRDBOSX: test_framework_GRDBOSX_maxSwift test_framework_GRDBOSX_minSwift

test_framework_GRDBOSX_maxSwift:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBOSX \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  'OTHER_SWIFT_FLAGS=$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK' \
	  'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1' \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBOSX_minSwift:
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBOSX \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  'OTHER_SWIFT_FLAGS=$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK' \
	  'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1' \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)
endif

test_framework_GRDBWatchOS:
	# XCTest is not supported for watchOS: we only make sure that the framework builds.
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBWatchOS \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  clean build \
	  $(XCPRETTY)

test_framework_GRDBiOS: test_framework_GRDBiOS_maxTarget test_framework_GRDBiOS_minTarget
test_framework_GRDBiOS_maxTarget: test_framework_GRDBiOS_maxTarget_maxSwift test_framework_GRDBiOS_maxTarget_minSwift

test_framework_GRDBiOS_maxTarget_maxSwift:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  'OTHER_SWIFT_FLAGS=$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK' \
	  'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1' \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBiOS_maxTarget_minSwift:
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  'OTHER_SWIFT_FLAGS=$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK' \
	  'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1' \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)
endif

test_framework_GRDBiOS_minTarget:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBiOS \
	  -destination $(MIN_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBtvOS: test_framework_GRDBtvOS_maxTarget test_framework_GRDBtvOS_minTarget
test_framework_GRDBtvOS_maxTarget: test_framework_GRDBtvOS_maxTarget_maxSwift test_framework_GRDBtvOS_maxTarget_minSwift

test_framework_GRDBtvOS_maxTarget_maxSwift:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBtvOS \
	  -destination $(MAX_TVOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  'OTHER_SWIFT_FLAGS=$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK' \
	  'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1' \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBtvOS_maxTarget_minSwift:
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBtvOS \
	  -destination $(MAX_TVOS_DESTINATION) \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  'OTHER_SWIFT_FLAGS=$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK' \
	  'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1' \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)
endif

test_framework_GRDBtvOS_minTarget:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBtvOS \
	  -destination $(MIN_TVOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBCustomSQLiteOSX: SQLiteCustom
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBCustomSQLiteOSX \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBCustomSQLiteiOS: test_framework_GRDBCustomSQLiteiOS_maxTarget test_framework_GRDBCustomSQLiteiOS_minTarget
test_framework_GRDBCustomSQLiteiOS_maxTarget: test_framework_GRDBCustomSQLiteiOS_maxTarget_maxSwift test_framework_GRDBCustomSQLiteiOS_maxTarget_minSwift

test_framework_GRDBCustomSQLiteiOS_maxTarget_maxSwift: SQLiteCustom
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBCustomSQLiteiOS_maxTarget_minSwift: SQLiteCustom
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)
endif

test_framework_GRDBCustomSQLiteiOS_minTarget: SQLiteCustom
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(MIN_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_SQLCipher3:
ifdef POD
	cd Tests/CocoaPods/SQLCipher3 && \
	$(POD) install && \
	$(XCODEBUILD) \
	  -workspace GRDBTests.xcworkspace \
	  -scheme GRDBTests \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  build-for-testing test-without-building \
	  $(XCPRETTY)
else
	@echo CocoaPods must be installed for test_framework_SQLCipher3
	@exit 1
endif

test_framework_SQLCipher4:
ifdef POD
	cd Tests/CocoaPods/SQLCipher4 && \
	$(POD) install && \
	$(XCODEBUILD) \
	  -workspace GRDBTests.xcworkspace \
	  -scheme GRDBTests \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  build-for-testing test-without-building \
	  $(XCPRETTY)
else
	@echo CocoaPods must be installed for test_framework_SQLCipher4
	@exit 1
endif

test_SPM:
	# Add sanitizers when available: https://twitter.com/simjp/status/929140877540278272
	$(SWIFT) package clean
	$(SWIFT) build
	$(SWIFT) build -c release
	set -o pipefail && $(SWIFT) test $(XCPRETTY)

test_install_manual:
	$(XCODEBUILD) \
	  -project Documentation/DemoApps/GRDBDemoiOS/GRDBDemoiOS.xcodeproj \
	  -scheme GRDBDemoiOS \
	  -configuration Release \
	  -destination $(MAX_IOS_DESTINATION) \
	  clean build \
	  $(XCPRETTY)

test_install_SPM: test_install_SPM_Package test_install_SPM_Project

test_install_SPM_Package:
	cd Tests/SPM/PlainPackage && \
	( if [ -a .build ] && [ -a Package.resolved ]; then $(SWIFT) package reset; fi ) && \
	rm -rf Packages/GRDB && \
	$(SWIFT) package edit GRDB --revision master && \
	rm -rf Packages/GRDB && \
	ln -s ../../../.. Packages/GRDB && \
	$(SWIFT) build && \
	./.build/debug/SPM && \
	$(SWIFT) package unedit --force GRDB

test_install_SPM_Project:
	$(XCODEBUILD) \
	  -project Tests/SPM/PlainProject/Plain.xcodeproj \
	  -scheme Plain \
	  -configuration Release \
	  clean build \
	  $(XCPRETTY)

test_install_customSQLite: SQLiteCustom
	$(XCODEBUILD) \
	  -project Tests/CustomSQLite/CustomSQLite.xcodeproj \
	  -scheme CustomSQLite \
	  -configuration Release \
	  clean build \
	  $(XCPRETTY)

test_install_GRDB_CocoaPods: test_install_GRDB_CocoaPods_framework test_install_GRDB_CocoaPods_static

test_install_GRDB_CocoaPods_framework:
ifdef POD
	cd Tests/CocoaPods/GRDBiOS-framework && \
	$(POD) install && \
	$(XCODEBUILD) \
	  -workspace iOS.xcworkspace \
	  -scheme iOS \
	  -configuration Release \
	  -destination $(MAX_IOS_DESTINATION) \
	  clean build \
	  $(XCPRETTY)
else
	@echo CocoaPods must be installed for test_install_GRDB_CocoaPods
	@exit 1
endif

test_install_GRDB_CocoaPods_static:
ifdef POD
	cd Tests/CocoaPods/GRDBiOS-static && \
	$(POD) install && \
	$(XCODEBUILD) \
	  -workspace iOS.xcworkspace \
	  -scheme iOS \
	  -configuration Release \
	  -destination $(MAX_IOS_DESTINATION) \
	  clean build \
	  $(XCPRETTY)
else
	@echo CocoaPods must be installed for test_install_GRDB_CocoaPods
	@exit 1
endif

test_CocoaPodsLint_GRDB:
ifdef POD
	$(POD) lib lint GRDB.swift.podspec --allow-warnings $(COCOAPODS_EXTRA_TIME)
else
	@echo CocoaPods must be installed for test_CocoaPodsLint_GRDB
	@exit 1
endif

test_performance: Realm FMDB SQLite.swift
	$(XCODEBUILD) \
	  -project Tests/Performance/GRDBPerformance/GRDBPerformance.xcodeproj \
	  -scheme GRDBOSXPerformanceComparisonTests \
	  build-for-testing test-without-building

Realm: Tests/Performance/Realm/build/osx/swift-11.3/RealmSwift.framework

# Makes sure the Tests/Performance/Realm submodule has been downloaded, and Realm framework has been built.
Tests/Performance/Realm/build/osx/swift-11.3/RealmSwift.framework:
	$(GIT) submodule update --init --recursive Tests/Performance/Realm
	cd Tests/Performance/Realm && sh build.sh osx-swift

FMDB: Tests/Performance/fmdb/src/fmdb/FMDatabase.h

# Makes sure the Tests/Performance/fmdb submodule has been downloaded
Tests/Performance/fmdb/src/fmdb/FMDatabase.h:
	$(GIT) submodule update --init Tests/Performance/fmdb

SQLite.swift: Tests/Performance/SQLite.swift/SQLite.xcodeproj

# Makes sure the Tests/Performance/SQLite.swift submodule has been downloaded
Tests/Performance/SQLite.swift/SQLite.xcodeproj:
	$(GIT) submodule update --init Tests/Performance/SQLite.swift

# Target that setups SQLite custom builds with extra compilation options.
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
	$(GIT) submodule update --init SQLiteCustom/src


# Documentation
# =============

doc:
ifdef JAZZY
	$(JAZZY) \
	  --clean \
	  --author 'Gwendal Roué' \
	  --author_url https://github.com/groue \
	  --github_url https://github.com/groue/GRDB.swift \
	  --github-file-prefix https://github.com/groue/GRDB.swift/tree/v4.10.0 \
	  --module-version 4.10.0 \
	  --module GRDB \
	  --root-url http://groue.github.io/GRDB.swift/docs/4.10/ \
	  --output Documentation/Reference \
	  --podspec GRDB.swift.podspec
else
	@echo Jazzy must be installed for doc
	@exit 1
endif


# Cleanup
# =======

distclean:
	$(GIT) reset --hard
	$(GIT) clean -dffx .
	rm -rf Tests/Performance/fmdb && $(GIT) checkout -- Tests/Performance/fmdb
	rm -rf Tests/Performance/SQLite.swift && $(GIT) checkout -- Tests/Performance/SQLite.swift
	rm -rf Tests/Performance/Realm && $(GIT) checkout -- Tests/Performance/Realm
	rm -rf SQLiteCustom/src && $(GIT) checkout -- SQLiteCustom/src

clean:
	$(SWIFT) package reset
	cd Tests/SPM && $(SWIFT) package reset
	rm -rf Documentation/Reference
	if [ -a Tests/Performance/Realm/build.sh ]; then cd Tests/Performance/Realm && sh build.sh clean; fi
	find . -name Package.resolved | xargs rm -f

.PHONY: distclean clean doc test SQLiteCustom
