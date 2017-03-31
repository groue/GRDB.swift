default: test

TEST_PROJECT = GRDB.xcodeproj
TEST_ACTIONS = clean build build-for-testing test-without-building
LATEST_SIMULATOR_DESTINATION = "platform=iOS Simulator,name=iPhone 7,OS=10.3"

test: test_GRDB test_GRDBCustom test_GRDBCipher
test_GRDB: test_GRDBOSX test_GRDBiOS
test_GRDBCustom: test_GRDBCustomSQLiteOSX test_GRDBCustomSQLiteiOS
test_GRDBCipher: test_GRDBCipherOSX test_GRDBCipheriOS
test_GRDBOSX:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBOSX \
	  $(TEST_ACTIONS)
test_GRDBiOS:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBiOS \
	  -destination $(LATEST_SIMULATOR_DESTINATION) \
	  $(TEST_ACTIONS)
test_GRDBCustomSQLiteOSX:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCustomSQLiteOSX \
	  $(TEST_ACTIONS)
test_GRDBCustomSQLiteiOS:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination $(LATEST_SIMULATOR_DESTINATION) \
	  $(TEST_ACTIONS)
test_GRDBCipherOSX:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCipherOSX \
	  $(TEST_ACTIONS)
test_GRDBCipheriOS:
	xcodebuild \
	  -project $(TEST_PROJECT) \
	  -scheme GRDBCipheriOS \
	  -destination $(LATEST_SIMULATOR_DESTINATION) \
	  $(TEST_ACTIONS)
# test_installationManual:
# 	xcodebuild \
# 	  -project DemoApps/GRDBDemoiOS/GRDBDemoiOS.xcodeproj \
# 	  -target GRDBDemoiOS \
# 	  -configuration Debug \
# 	  -destination $(LATEST_SIMULATOR_DESTINATION) \
# 	  clean build

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
