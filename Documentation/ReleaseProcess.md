Release Process
===============

**This is internal documentation.**

To release a new GRDB version:

- Tests
    - Run GRDBOX tests
    - Run GRDBCipherOSX tests
    - Run GRDBCustomSQLiteOSX tests
    - Run GRDBiOS tests
    - Run GRDBCipheriOS tests
    - Run GRDBCustomSQLiteiOS tests
    - Build and run GRDBDemoiOS
    - Build and run GRDBDemoWatchOS
    - Check for performance regression with GRDBOSXPerformanceTests
    - `rm -rf Carthage; carthage build --no-skip-current`
    - `pod lib lint --allow-warnings`
- On https://github.com/groue/sqlcipher.git upgrade, update SQLCipher version in README.md
- On https://github.com/swiftlyfalling/SQLiteLib upgrade, update SQLite version in README.md and Documentation/CustomSQLiteBuilds.md
- Update GRDB version number and release date in:
    - CHANGELOG.md
    - Documentation/CustomSQLiteBuilds.md
    - Documentation/ExtendingGRDB.md
    - GRDB.swift.podspec
    - README.md
    - Support/Info.plist
- Commit and tag
- Push to the master branch
- Push to the Swift3 branch
- `pod trunk push --allow-warnings`
- Update http://github.com/groue/GRDBDemo
- Update http://github.com/groue/WWDCCompanion
