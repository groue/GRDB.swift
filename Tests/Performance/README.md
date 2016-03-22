Performance Tests
=================

To run those tests, install FMDB, SQLite.swift, and Realm:

```sh
git submodule update --init
cd Tests/Performance/Realm
sh build.sh osx-swift
```

Then open GRDB.xcworkspace, and test the GRDBOSXPerformanceTests target.
