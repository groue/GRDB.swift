Release Process
===============

**This is internal documentation.**

To release a new GRDB version:

- Tests
    - `make test`
    - Build and run GRDBDemoiOS in Release configuration on a device
    - Archive GRDBDemoiOS
    - Check for performance regression with GRDBOSXPerformanceTests
- On SDK upgrade, update Support/sqlite3.h
- On https://github.com/groue/sqlcipher.git upgrade, update SQLCipher version in README.md
- On https://github.com/swiftlyfalling/SQLiteLib upgrade, update SQLite version in README.md and Documentation/CustomSQLiteBuilds.md
- Update GRDB version number and release date in:
    - Makefile
    - CHANGELOG.md
    - Documentation/CustomSQLiteBuilds.md
    - Documentation/ExtendingGRDB.md
    - GRDB.swift.podspec
    - GRDBCipher.podspec
    - README.md
    - Support/Info.plist
- Commit and tag
- Check tag authors: `git for-each-ref --format '%(refname) %(authorname)' refs/tags`
- Push to the master branch
- Push to the Swift3 branch
- `pod trunk push --allow-warnings GRDB.swift.podspec`
- `pod trunk push --allow-warnings GRDBCipher.podspec`
- `make doc`, and update index.html in the `gh-pages` branch
- Update http://github.com/groue/GRDBDemo
- Update http://github.com/groue/WWDCCompanion
