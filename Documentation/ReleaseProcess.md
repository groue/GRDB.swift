Release Process
===============

**This is internal documentation.**

To release a new GRDB version:

- Tests
    - `make distclean test`
    - Build and run GRDBDemoiOS in Release configuration on a device
    - Archive GRDBDemoiOS
    - Check for performance regression with GRDBOSXPerformanceTests
- On https://github.com/groue/sqlcipher.git upgrade, update SQLCipher version in README.md
- On https://github.com/swiftlyfalling/SQLiteLib upgrade, update SQLite version in Documentation/CustomSQLiteBuilds.md
- Update GRDB version number and release date in:
    - CHANGELOG.md
    - GRDB.swift.podspec
    - README.md
    - Support/Info.plist
- Commit and tag
- Check tag authors: `git for-each-ref --format '%(refname) %(authorname)' refs/tags`
- Push to the master & development branch
- `pod trunk push --allow-warnings GRDB.swift.podspec`
- Update [performance comparison](https://github.com/groue/GRDB.swift/wiki/Performance):

    `make test_performance | Tests/parsePerformanceTests.rb | Tests/generatePerformanceReport.rb`
