# Rules
# =====
#
# make test - Run all tests but performance tests
# make test_performance - Run performance tests
# make doc - Generate DocC documentation
# make clean - Remove build artifacts
# make distclean - Restore repository to a pristine state

default: test
smokeTest: test_framework_GRDBiOS_maxTarget test_framework_GRDBiOS_minTarget test_framework_SQLCipher3 test_framework_SQLCipher4Encrypted test_framework_GRDBCustomSQLiteiOS_maxTarget test_SPM

# =====
# Tools

GIT := $(shell command -v git)
POD := $(shell command -v pod)
XCRUN := $(shell command -v xcrun)
XCODEBUILD := set -o pipefail && $(shell command -v xcodebuild)

ifdef TOOLCHAIN
  # Look for the toolchain identifier in the CFBundleIdentifier key of its Info.plist:
  # TOOLCHAIN=org.swift.600202404221a make test
  
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

# =====
# Configuration

DOCS_PATH = Documentation/Reference

TEST_ACTIONS = clean build build-for-testing test-without-building

OTHER_SWIFT_FLAGS = '$$(inherited) -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK' # -Xfrontend -warn-concurrency -Xfrontend -enable-actor-data-race-checks'
GCC_PREPROCESSOR_DEFINITIONS = '$$(inherited) GRDB_SQLITE_ENABLE_PREUPDATE_HOOK=1'

# Extract min and max destinations from the available devices
MIN_IOS_DESTINATION := $(shell xcrun simctl list -j devices available | Scripts/destination.rb | grep iPhone | grep -v ^13\.7 | sort -n | head -1 | cut -wf 3 | sed 's/\(.*\)/"platform=iOS Simulator,id=\1"/')
MAX_IOS_DESTINATION := $(shell xcrun simctl list -j devices available | Scripts/destination.rb | grep iPhone | grep -v ^13\.7 | sort -rn | head -1 | cut -wf 3 | sed 's/\(.*\)/"platform=iOS Simulator,id=\1"/')
MIN_TVOS_DESTINATION := $(shell xcrun simctl list -j devices available | Scripts/destination.rb | grep tvOS | sort -n | head -1 | cut -wf 3 | sed 's/\(.*\)/"platform=tvOS Simulator,id=\1"/')
MAX_TVOS_DESTINATION := $(shell xcrun simctl list -j devices available | Scripts/destination.rb | grep tvOS | sort -rn | head -1 | cut -wf 3 | sed 's/\(.*\)/"platform=tvOS Simulator,id=\1"/')

  # If xcbeautify or xcpretty is available, use it for xcodebuild output, except in CI.
XCPRETTY =
ifeq ($(CI),true)
else
  XCBEAUTIFY_PATH := $(shell command -v xcbeautify 2> /dev/null)
  XCPRETTY_PATH := $(shell command -v xcpretty 2> /dev/null)
  ifdef XCBEAUTIFY_PATH
    XCPRETTY = | xcbeautify
  else ifdef XCPRETTY_PATH
    XCPRETTY = | xcpretty -c
  endif
endif

# =====
# Tests

test: test_framework test_archive test_install test_demo_apps

test_framework: test_framework_darwin
test_framework_darwin: test_framework_GRDB test_framework_GRDBCustom test_framework_SQLCipher test_SPM
test_framework_GRDB: test_framework_GRDBOSX test_framework_GRDBiOS test_framework_GRDBtvOS
test_framework_GRDBCustom: test_framework_GRDBCustomSQLiteOSX test_framework_GRDBCustomSQLiteiOS
test_framework_SQLCipher: test_framework_SQLCipher3 test_framework_SQLCipher3Encrypted test_framework_SQLCipher4 test_framework_SQLCipher4Encrypted
test_archive: test_universal_xcframework
test_install: test_install_manual test_install_SPM test_install_customSQLite test_install_GRDB_CocoaPods
test_CocoaPodsLint: test_CocoaPodsLint_GRDB
test_demo_apps: test_GRDBDemo

test_framework_GRDBOSX:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDB \
	  -destination "platform=macOS" \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBiOS: test_framework_GRDBiOS_maxTarget test_framework_GRDBiOS_minTarget

test_framework_GRDBiOS_maxTarget:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDB \
	  -destination $(MAX_IOS_DESTINATION) \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBiOS_minTarget:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDB \
	  -destination $(MIN_IOS_DESTINATION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBtvOS: test_framework_GRDBtvOS_maxTarget test_framework_GRDBtvOS_minTarget

test_framework_GRDBtvOS_maxTarget:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDB \
	  -destination $(MAX_TVOS_DESTINATION) \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBtvOS_minTarget:
	$(XCODEBUILD) \
	  -project GRDB.xcodeproj \
	  -scheme GRDB \
	  -destination $(MIN_TVOS_DESTINATION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBCustomSQLiteOSX: SQLiteCustom
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBCustom \
	  -destination "platform=macOS" \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBCustomSQLiteiOS: test_framework_GRDBCustomSQLiteiOS_maxTarget test_framework_GRDBCustomSQLiteiOS_minTarget

test_framework_GRDBCustomSQLiteiOS_maxTarget: SQLiteCustom
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBCustom \
	  -destination $(MAX_IOS_DESTINATION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_GRDBCustomSQLiteiOS_minTarget: SQLiteCustom
	$(XCODEBUILD) \
	  -project GRDBCustom.xcodeproj \
	  -scheme GRDBCustom \
	  -destination $(MIN_IOS_DESTINATION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_framework_SQLCipher3:
ifdef POD
	cd Tests/CocoaPods/SQLCipher3 && \
	$(POD) install && \
	$(XCODEBUILD) \
	  -workspace GRDBTests.xcworkspace \
	  -scheme GRDBTests \
	  build-for-testing test-without-building \
	  $(XCPRETTY)
else
	@echo CocoaPods must be installed for test_framework_SQLCipher3
	@exit 1
endif

test_framework_SQLCipher3Encrypted:
ifdef POD
	cd Tests/CocoaPods/SQLCipher3 && \
	$(POD) install && \
	$(XCODEBUILD) \
	  -workspace GRDBTests.xcworkspace \
	  -scheme GRDBEncryptedTests \
	  build-for-testing test-without-building \
	  $(XCPRETTY)
else
	@echo CocoaPods must be installed for test_framework_SQLCipher3Encrypted
	@exit 1
endif

test_framework_SQLCipher4:
ifdef POD
	cd Tests/CocoaPods/SQLCipher4 && \
	$(POD) install && \
	$(XCODEBUILD) \
	  -workspace GRDBTests.xcworkspace \
	  -scheme GRDBTests \
	  build-for-testing test-without-building \
	  $(XCPRETTY)
else
	@echo CocoaPods must be installed for test_framework_SQLCipher4
	@exit 1
endif

test_framework_SQLCipher4Encrypted:
ifdef POD
	cd Tests/CocoaPods/SQLCipher4 && \
	$(POD) install && \
	$(XCODEBUILD) \
	  -workspace GRDBTests.xcworkspace \
	  -scheme GRDBEncryptedTests \
	  build-for-testing test-without-building \
	  $(XCPRETTY)
else
	@echo CocoaPods must be installed for test_framework_SQLCipher4Encrypted
	@exit 1
endif

test_SPM:
	# Add sanitizers when available: https://twitter.com/simjp/status/929140877540278272
	rm -rf Tests/products
	$(SWIFT) package clean
	$(SWIFT) build
	$(SWIFT) build -c release
	set -o pipefail && $(SWIFT) test --parallel

test_universal_xcframework:
	rm -rf Tests/products
	mkdir Tests/products
	$(XCODEBUILD) archive \
	  -project GRDB.xcodeproj \
	  -scheme GRDB \
	  -destination "generic/platform=iOS" \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  -archivePath "$(PWD)/Tests/products/GRDB-iOS.xcarchive" \
	  SKIP_INSTALL=NO \
	  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	$(XCODEBUILD) archive \
	  -project GRDB.xcodeproj \
	  -scheme GRDB \
	  -destination "generic/platform=iOS Simulator" \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  -archivePath "$(PWD)/Tests/products/GRDB-iOS_Simulator.xcarchive" \
	  SKIP_INSTALL=NO \
	  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	$(XCODEBUILD) archive \
	  -project GRDB.xcodeproj \
	  -scheme GRDB \
	  -destination "generic/platform=macOS" \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  -archivePath "$(PWD)/Tests/products/GRDB-macOS.xcarchive" \
	  SKIP_INSTALL=NO \
	  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	$(XCODEBUILD) archive \
	  -project GRDB.xcodeproj \
	  -scheme GRDB \
	  -destination "generic/platform=macOS,variant=Mac Catalyst" \
	  OTHER_SWIFT_FLAGS=$(OTHER_SWIFT_FLAGS) \
	  GCC_PREPROCESSOR_DEFINITIONS=$(GCC_PREPROCESSOR_DEFINITIONS) \
	  -archivePath "$(PWD)/Tests/products/GRDB-Mac_Catalyst.xcarchive" \
	  SKIP_INSTALL=NO \
	  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	$(XCODEBUILD) -create-xcframework \
      -archive '$(PWD)/Tests/products/GRDB-iOS.xcarchive' -framework GRDB.framework \
      -archive '$(PWD)/Tests/products/GRDB-iOS_Simulator.xcarchive' -framework GRDB.framework \
      -archive '$(PWD)/Tests/products/GRDB-macOS.xcarchive' -framework GRDB.framework \
      -archive '$(PWD)/Tests/products/GRDB-Mac_Catalyst.xcarchive' -framework GRDB.framework \
      -output '$(PWD)/Tests/products/GRDB.xcframework'

test_install_manual:
	$(XCODEBUILD) \
	  -project Tests/GRDBManualInstall/GRDBManualInstall.xcodeproj \
	  -scheme GRDBManualInstall \
	  -configuration Release \
	  -destination "platform=macOS" \
	  clean build \
	  $(XCPRETTY)

test_install_SPM: test_install_SPM_Package test_install_SPM_Project test_install_SPM_Dynamic_Project test_install_SPM_macos_release test_install_SPM_ios_release

test_install_SPM_Package:
	rm -rf Tests/products
	cd Tests/SPM/PlainPackage && \
	$(SWIFT) build && \
	./.build/debug/SPM

test_install_SPM_Project:
	rm -rf Tests/products
	$(XCODEBUILD) \
	  -project Tests/SPM/PlainProject/Plain.xcodeproj \
	  -scheme Plain \
	  -destination "platform=macOS" \
	  -configuration Release \
	  clean build \
	  $(XCPRETTY)
	  
test_install_SPM_Dynamic_Project:
	rm -rf Tests/products
	$(XCODEBUILD) \
	  -project Tests/SPM/ios-dynamic/ios-dynamic.xcodeproj \
	  -scheme ios-dynamic \
	  -destination $(MAX_IOS_DESTINATION) \
	  -configuration Release \
	  clean build \
	  $(XCPRETTY)

test_install_SPM_macos_release:
	rm -rf Tests/products
	$(XCODEBUILD) \
	  -project Tests/SPM/macos/macos.xcodeproj \
	  -scheme macos \
	  -destination "platform=macOS" \
	  -configuration Release \
	  clean build \
	  $(XCPRETTY)

test_install_SPM_ios_release:
	rm -rf Tests/products
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
	  -destination "platform=macOS" \
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
	$(POD) lib lint GRDB.swift.podspec --allow-warnings
else
	@echo CocoaPods must be installed for test_CocoaPodsLint_GRDB
	@exit 1
endif

test_GRDBDemo:
	$(XCODEBUILD) \
	  -project Documentation/DemoApps/GRDBDemo/GRDBDemo.xcodeproj \
	  -scheme GRDBDemo \
	  -destination $(MAX_IOS_DESTINATION) \
	  $(TEST_ACTIONS) \
	  $(XCPRETTY)

test_performance:
	$(XCODEBUILD) \
	  -project Tests/Performance/GRDBPerformance/GRDBPerformance.xcodeproj \
	  -scheme GRDBOSXPerformanceComparisonTests \
	  -destination "platform=macOS" \
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

doc-localhost:
	# Generates documentation in ~/Sites/GRDB
	# See https://discussions.apple.com/docs/DOC-3083 for Apache setup on the mac
	mkdir -p ~/Sites/GRDB
	SPI_BUILDER=1 $(SWIFT) package \
	  --allow-writing-to-directory ~/Sites/GRDB \
	  generate-documentation \
	  --output-path ~/Sites/GRDB \
	  --target GRDB \
	  --disable-indexing \
	  --transform-for-static-hosting \
	  --hosting-base-path "~$(USER)/GRDB"
	open "http://localhost/~$(USER)/GRDB/documentation/grdb/"

doc:
	# https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/publishing-to-github-pages/
	rm -rf $(DOCS_PATH)
	mkdir -p $(DOCS_PATH)
	SPI_BUILDER=1 $(SWIFT) package \
	  --allow-writing-to-directory $(DOCS_PATH) \
	  generate-documentation \
	  --output-path $(DOCS_PATH) \
	  --target GRDB \
	  --disable-indexing \
	  --transform-for-static-hosting \
	  --hosting-base-path GRDB.swift/docs/6.3


# Cleanup
# =======

distclean:
	$(GIT) reset --hard
	$(GIT) clean -dffx .
	rm -rf SQLiteCustom/src && $(GIT) checkout -- SQLiteCustom/src

clean:
	$(SWIFT) package reset
	cd Tests/SPM && $(SWIFT) package reset
	rm -rf $(DOCS_PATH)
	find . -name Package.resolved | xargs rm -f

.PHONY: distclean clean doc test smokeTest SQLiteCustom
