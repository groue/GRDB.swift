# Rules
# =====
#
# make test - Run all tests but performance tests
# make test_performance - Run performance tests
# make documentation - Generate jazzy documentation
# make clean - Remove build artifacts
# make distclean - Restore repository to a pristine state

default: test
smokeTest: test_framework_GRDBiOS_maxTarget test_framework_GRDBiOS_minTarget test_framework_SQLCipher4 test_framework_GRDBCustomSQLiteiOS_maxTarget test_SPM

# Requirements
# ============
#
# Xcode
# CocoaPods - https://cocoapods.org
# Jazzy - https://github.com/realm/jazzy

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

# When adding support for an Xcode version, look for available devices with
# `xcrun xctrace list devices` (or the deprecated `instruments -s devices`).
ifeq ($(XCODEVERSION),13.3)
  MAX_SWIFT_VERSION = 5.6
  MIN_SWIFT_VERSION = 5.3
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 13,OS=15.4"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=13.7"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=15.4"
  #MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=11.4" TODO: restore
  OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK -Xfrontend -warn-concurrency -Xfrontend -enable-actor-data-race-checks'
  GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'
else ifeq ($(XCODEVERSION),13.2)
  MAX_SWIFT_VERSION = 5.5
  MIN_SWIFT_VERSION = 5.3
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 13,OS=15.2"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=13.7"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=15.2"
  #MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=11.4" TODO: restore
  OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK -Xfrontend -warn-concurrency -Xfrontend -enable-actor-data-race-checks'
  GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'
else ifeq ($(XCODEVERSION),13.1)
  MAX_SWIFT_VERSION = 5.5
  MIN_SWIFT_VERSION = 5.3
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 13,OS=15.0"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 8,OS=13.7"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=15.0"
  #MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=11.4" TODO: restore
  OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK'
  GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'
else ifeq ($(XCODEVERSION),13.0)
  MAX_SWIFT_VERSION = 5.5
  MIN_SWIFT_VERSION = 5.3
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 13,OS=15.0"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5s,OS=11.4"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=15.0"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=11.4"
  OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK'
  GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'
else ifeq ($(XCODEVERSION),12.5)
  MAX_SWIFT_VERSION = 5.4
  MIN_SWIFT_VERSION = 5.3
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 12,OS=14.5"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5s,OS=11.4"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=14.5"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=11.4"
  OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK'
  GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'
else ifeq ($(XCODEVERSION),12.4)
  MAX_SWIFT_VERSION = 5.3
  MIN_SWIFT_VERSION = # MAX_SWIFT_VERSION is the minimum supported Swift version
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 12,OS=14.4"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5s,OS=11.4"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=14.3"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=11.4"
  OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK'
  GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'
else ifeq ($(XCODEVERSION),12.3)
  MAX_SWIFT_VERSION = 5.3
  MIN_SWIFT_VERSION = # MAX_SWIFT_VERSION is the minimum supported Swift version
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 12,OS=14.3"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5s,OS=10.3.1"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=14.3"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.2"
  OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK'
  GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'
else ifeq ($(XCODEVERSION),12.2)
  MAX_SWIFT_VERSION = 5.3
  MIN_SWIFT_VERSION = # MAX_SWIFT_VERSION is the minimum supported Swift version
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 12,OS=14.2"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5s,OS=10.3.1"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=14.2"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.2"
  OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK'
  GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'
else ifeq ($(XCODEVERSION),12.0)
  MAX_SWIFT_VERSION = 5.3
  MIN_SWIFT_VERSION = # MAX_SWIFT_VERSION is the minimum supported Swift version
  MAX_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 11,OS=14.0"
  MIN_IOS_DESTINATION = "platform=iOS Simulator,name=iPhone 5s,OS=10.3.1"
  MAX_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV 4K,OS=14.0"
  MIN_TVOS_DESTINATION = "platform=tvOS Simulator,name=Apple TV,OS=10.2"
  OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK'
  GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'
else
  # Swift 5.3 required: Xcode < 12.0 is not supported
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
test: test_framework test_archive test_install test_demo_apps

test_framework: test_framework_darwin
test_framework_darwin: test_framework_GRDB test_framework_GRDBCustom test_framework_SQLCipher test_SPM
test_framework_GRDB: test_framework_GRDBOSX test_framework_GRDBWatchOS test_framework_GRDBiOS test_framework_GRDBtvOS
test_framework_GRDBCustom: test_framework_GRDBCustomSQLiteOSX test_framework_GRDBCustomSQLiteiOS
test_framework_SQLCipher: test_framework_SQLCipher3 test_framework_SQLCipher4
test_archive: test_archive_GRDBOSX_xcframework
test_install: test_install_manual test_install_SPM test_install_customSQLite test_install_GRDB_CocoaPods test_CocoaPodsLint
test_CocoaPodsLint: test_CocoaPodsLint_GRDB
test_demo_apps: test_GRDBDemoiOS test_GRDBCombineDemo test_GRDBAsyncDemo

test_framework_GRDBOSX: test_framework_GRDBOSX_maxSwift test_framework_GRDBOSX_minSwift

test_framework_GRDBOSX_maxSwift:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBOSX \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBOSX_minSwift:
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBOSX \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
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
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBiOS_maxTarget_minSwift:
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
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
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBtvOS_maxTarget_minSwift:
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBtvOS \
	  -destination $(MAX_TVOS_DESTINATION) \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)
endif

test_framework_GRDBtvOS_minTarget:
ifdef MIN_TVOS_DESTINATION
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDBtvOS \
	  -destination $(MIN_TVOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)
endif

test_framework_GRDBCustomSQLiteOSX: SQLiteCustom
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBOSX \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBCustomSQLiteiOS: test_framework_GRDBCustomSQLiteiOS_maxTarget test_framework_GRDBCustomSQLiteiOS_minTarget
test_framework_GRDBCustomSQLiteiOS_maxTarget: test_framework_GRDBCustomSQLiteiOS_maxTarget_maxSwift test_framework_GRDBCustomSQLiteiOS_maxTarget_minSwift

test_framework_GRDBCustomSQLiteiOS_maxTarget_maxSwift: SQLiteCustom
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBCustomSQLiteiOS_maxTarget_minSwift: SQLiteCustom
ifdef MIN_SWIFT_VERSION
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MIN_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)
endif

test_framework_GRDBCustomSQLiteiOS_minTarget: SQLiteCustom
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBiOS \
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

test_archive_GRDBOSX_xcframework:
	rm -rf Tests/products
	mkdir Tests/products
	$(XCODEBUILD) archive \
	  -project GRDB.xcodeproj \
	  -scheme GRDBOSX \
	  -configuration Release \
	  -destination "generic/platform=macOS" \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  -archivePath "$(PWD)/Tests/products/GRDB.xcarchive" \
	  SKIP_INSTALL=NO \
	  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	$(XCODEBUILD) -create-xcframework \
	  -framework '$(PWD)/Tests/products/GRDB.xcarchive/Products/Library/Frameworks/GRDB.framework' \
	  -output '$(PWD)/Tests/products/GRDB.xcframework'

test_install_manual:
	$(XCODEBUILD) \
	  -project Documentation/DemoApps/GRDBDemoiOS/GRDBDemoiOS.xcodeproj \
	  -scheme GRDBDemoiOS \
	  -configuration Release \
	  -destination $(MAX_IOS_DESTINATION) \
	  clean build \
	  $(XCPRETTY)

test_install_SPM: test_install_SPM_Package test_install_SPM_Project test_install_SPM_Dynamic_Project test_install_SPM_macos_release test_install_SPM_ios_release

test_install_SPM_Package:
	cd Tests/SPM/PlainPackage && \
	$(SWIFT) build && \
	./.build/debug/SPM

test_install_SPM_Project:
	$(XCODEBUILD) \
	  -project Tests/SPM/PlainProject/Plain.xcodeproj \
	  -scheme Plain \
	  -configuration Release \
	  clean build \
	  $(XCPRETTY)
	  
test_install_SPM_Dynamic_Project:
	$(XCODEBUILD) \
	  -project Tests/SPM/ios-dynamic/ios-dynamic.xcodeproj \
	  -scheme ios-dynamic \
	  -destination $(MAX_IOS_DESTINATION) \
	  -configuration Release \
	  clean build \
	  $(XCPRETTY)

test_install_SPM_macos_release:
	$(XCODEBUILD) \
	  -project Tests/SPM/macos/macos.xcodeproj \
	  -scheme macos \
	  -configuration Release \
	  clean build \
	  $(XCPRETTY)

test_install_SPM_ios_release:
	$(XCODEBUILD) \
	  -project Tests/SPM/ios/ios.xcodeproj \
	  -scheme ios \
	  -destination $(MAX_IOS_DESTINATION) \
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

test_GRDBDemoiOS:
	$(XCODEBUILD) \
	  -project Documentation/DemoApps/GRDBDemoiOS/GRDBDemoiOS.xcodeproj \
	  -scheme GRDBDemoiOS \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_GRDBCombineDemo:
	$(XCODEBUILD) \
	  -project Documentation/DemoApps/GRDBCombineDemo/GRDBCombineDemo.xcodeproj \
	  -scheme GRDBCombineDemo \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_GRDBAsyncDemo:
	$(XCODEBUILD) \
	  -project Documentation/DemoApps/GRDBAsyncDemo/GRDBAsyncDemo.xcodeproj \
	  -scheme GRDBAsyncDemo \
	  -destination $(MAX_IOS_DESTINATION) \
	  SWIFT_VERSION=$(MAX_SWIFT_VERSION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_performance:
	$(XCODEBUILD) \
	  -project Tests/Performance/GRDBPerformance/GRDBPerformance.xcodeproj \
	  -scheme GRDBOSXPerformanceComparisonTests \
	  build-for-testing test-without-building

# Target that setups SQLite custom builds with extra compilation options.
SQLiteCustom: SQLiteCustom/src/sqlite3.h
	echo '/* Makefile generated */' > SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '#define SQLITE_ENABLE_PREUPDATE_HOOK' >> SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '#define SQLITE_ENABLE_FTS5' >> SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '#define SQLITE_ENABLE_SNAPSHOT' >> SQLiteCustom/GRDBCustomSQLite-USER.h
	echo '// Makefile generated' > SQLiteCustom/GRDBCustomSQLite-USER.xcconfig
	echo 'CUSTOM_OTHER_SWIFT_FLAGS = -D SQLITE_ENABLE_PREUPDATE_HOOK -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_SNAPSHOT' >> SQLiteCustom/GRDBCustomSQLite-USER.xcconfig
	echo '// Makefile generated' > SQLiteCustom/src/SQLiteLib-USER.xcconfig
	echo 'CUSTOM_SQLLIBRARY_CFLAGS = -DSQLITE_ENABLE_PREUPDATE_HOOK -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_SNAPSHOT' >> SQLiteCustom/src/SQLiteLib-USER.xcconfig

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
	  --github-file-prefix https://github.com/groue/GRDB.swift/tree/v5.22.1 \
	  --module-version 5.22.1 \
	  --module GRDB \
	  --root-url http://groue.github.io/GRDB.swift/docs/5.22/ \
	  --output Documentation/Reference \
	  --xcodebuild-arguments -project,GRDB.xcodeproj,-scheme,GRDBiOS
else
	@echo Jazzy must be installed for doc
	@exit 1
endif


# Cleanup
# =======

distclean:
	$(GIT) reset --hard
	$(GIT) clean -dffx .
	rm -rf SQLiteCustom/src && $(GIT) checkout -- SQLiteCustom/src

clean:
	$(SWIFT) package reset
	cd Tests/SPM && $(SWIFT) package reset
	rm -rf Documentation/Reference
	find . -name Package.resolved | xargs rm -f

.PHONY: distclean clean doc test smokeTest SQLiteCustom
