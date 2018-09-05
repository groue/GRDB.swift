Release Process
===============

**This is internal documentation.**

To release a new GRDB version:

- Tests
    - `make test`
    - Build and run GRDBDemoiOS in Release configuration on a device
    - Archive GRDBDemoiOS
    - Check for performance regression with GRDBOSXPerformanceTests
- On https://github.com/groue/sqlcipher.git upgrade, update SQLCipher version in README.md
- On https://github.com/swiftlyfalling/SQLiteLib upgrade, update SQLite version in README.md and Documentation/CustomSQLiteBuilds.md
- Update GRDB version number and release date in:
    - Makefile
    - CHANGELOG.md
    - Documentation/CustomSQLiteBuilds.md
    - GRDB.swift.podspec
    - GRDBCipher.podspec
    - GRDBPlus.podspec
    - README.md
    - Support/Info.plist
- Commit and tag
- Check tag authors: `git for-each-ref --format '%(refname) %(authorname)' refs/tags`
- Push to the master branch
- `pod trunk push --allow-warnings GRDB.swift.podspec`
- `pod trunk push --allow-warnings GRDBPlus.podspec`
- `pod trunk push --allow-warnings GRDBCipher.podspec`
- `make doc`, and update index.html in the `gh-pages` branch
- Update http://github.com/groue/GRDBDemo
- Update http://github.com/groue/WWDCCompanion
- Update [performance comparison](https://github.com/groue/GRDB.swift/wiki/Performance):

    `make test_performance | Tests/parsePerformanceTests.rb | Tests/generatePerformanceReport.rb`
