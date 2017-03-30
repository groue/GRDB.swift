default: test

# GRDBOSX, GRDBCipherOSX, GRDBCustomSQLiteOSX, GRDBiOS, GRDBCipheriOS, GRDBCustomSQLiteiOS
test: test_GRDB test_GRDBCustom test_GRDBCipher
test_GRDB: test_GRDBOSX test_GRDBiOS
test_GRDBCustom: test_GRDBCustomSQLiteOSX test_GRDBCustomSQLiteiOS
test_GRDBCipher: test_GRDBCipherOSX test_GRDBCipheriOS
test_GRDBOSX:
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBOSX \
	  clean build build-for-testing test-without-building
test_GRDBiOS:
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBiOS \
	  -destination "platform=iOS Simulator,name=iPhone 6s,OS=10.3" \
	  clean build build-for-testing test-without-building
test_GRDBCustomSQLiteOSX:
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCustomSQLiteOSX \
	  clean build build-for-testing test-without-building
test_GRDBCustomSQLiteiOS:
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCustomSQLiteiOS \
	  -destination "platform=iOS Simulator,name=iPhone 6s,OS=10.3" \
	  clean build build-for-testing test-without-building
test_GRDBCipherOSX:
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCipherOSX \
	  clean build build-for-testing test-without-building
test_GRDBCipheriOS:
	xcodebuild \
	  -project GRDB.xcodeproj \
	  -scheme GRDBCipheriOS \
	  -destination "platform=iOS Simulator,name=iPhone 6s,OS=10.3" \
	  clean build build-for-testing test-without-building
test_installationManual:
	xcodebuild \
	  -project DemoApps/GRDBDemoiOS/GRDBDemoiOS.xcodeproj \
	  -target GRDBDemoiOS \
	  -configuration Debug \
	  -destination "platform=iOS Simulator,name=iPhone 6s,OS=10.3" \
	  clean build
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
