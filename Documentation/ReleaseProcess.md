Release Process
===============

**This is internal documentation.**

To release a new GRDB version:

- Tests
    - Run GRDBOX tests
    - Run GRDBiOS tests
    - Run GRDBCustomSQLiteOSX tests
    - Run GRDBCustomSQLiteiOS tests
    - Run GRDBCipherOSX tests
    - Run GRDBCipheriOS tests
    - Build and run GRDBDemoiOS
    - Build and run GRDBDemoWatchOS
    - `rm -rf Carthage; carthage build --no-skip-current`
    - `pod lib lint --allow-warnings`
- Update version number and release date in:
    - README.md
    - CHANGELOG.md
    - Documentation/CustomSQLiteBuilds.md
    - Support/Info.plist
    - GRDB.swift.podspec
- Commit and tag
- Push to the master branch
- Push to the Swift3 branch
- `pod trunk push --allow-warnings`
