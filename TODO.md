- [ ] Swift 3.0.2 (Xcode 8.2): "Type inference will properly unwrap optionals when used with generics and implicitly-unwrapped optionals." Maybe this fixes `row.value(named: "foo") as? Int`?
- [ ] Refactor Database notion of transaction/savepoints into a single type. Support INSERT OR ROLLBACK.
- [ ] Attach databases (this could be the support for fetched records controller caches). Interesting question: what happens when one attaches a non-WAL db to a databasePool?
- [ ] sqlite3_rekey is discouraged (https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320)
- [ ] ROUND function: read http://marc.info/?l=sqlite-users&m=130419182719263
- [ ] Remove DatabaseWriter.writeForIssue117 when https://bugs.swift.org/browse/SR-2623 is fixed (remove `writeForIssue117`, use `write` instead, and build in Release configuration) 
- [ ] Restore dispatching tests in GRDBOSXTests (they are disabled in order to avoid linker errors)
    - DatabasePoolReleaseMemoryTests
    - DatabasePoolSchemaCacheTests
    - DatabaseQueueReleaseMemoryTests
    - DatabasePoolBackupTests
    - DatabasePoolConcurrencyTests
    - DatabasePoolReadOnlyTests
    - DatabaseQueueConcurrencyTests
- [ ] FetchedRecordsController throttling (suggested by @hdlj)
- [ ] What is the behavior inTransaction and inSavepoint behaviors in case of commit error? Code looks like we do not rollback, leaving the app in a weird state (out of Swift transaction block with a SQLite transaction that may still be opened).
- [ ] GRDBCipher / custom SQLite builds: remove limitations on iOS or OS X versions
- [ ] File protection: Read https://github.com/ccgus/fmdb/issues/262 and understand https://lists.apple.com/archives/cocoa-dev/2012/Aug/msg00527.html
- [ ] Support for resource values (see https://developer.apple.com/library/ios/qa/qa1719/_index.html)
- [ ] Query builder
    - [ ] SELECT readers.*, books.* FROM ... JOIN ...
    - [ ] date functions
    - [ ] NOW
    - [ ] RANDOM() https://www.sqlite.org/lang_corefunc.html
    - [ ] GLOB https://www.sqlite.org/lang_expr.html
    - [ ] REGEXP https://www.sqlite.org/lang_expr.html
    - [ ] CASE x WHEN w1 THEN r1 WHEN w2 THEN r2 ELSE r3 END https://www.sqlite.org/lang_expr.html


Not sure

- [X] Have Row adopt LiteralDictionaryConvertible
    - [ ] ... allowing non unique column names
- [ ] Remove DatabaseValue.value()
    - [X] Don't talk about DatabaseValue.value() in README.md
- [ ] Support for NSColor/UIColor. Beware UIColor components can go beyond [0, 1.0] in iOS10.
- [ ] Store dates as timestamp (https://twitter.com/gloparco/status/780948021613912064, https://github.com/groue/GRDB.swift/issues/97)

Require changes in the Swift language:

- [ ] Specific and optimized Optional<StatementColumnConvertible>.fetch... methods when http://openradar.appspot.com/22852669 is fixed.


Requires recompilation of SQLite:

- [ ] https://www.sqlite.org/c3ref/column_database_name.html could help extracting out of a row a subrow only made of columns that come from a specific table. Requires SQLITE_ENABLE_COLUMN_METADATA which is not set on the sqlite3 lib that ships with OSX.



Reading list:

- VACUUM (https://blogs.gnome.org/jnelson/)
- Full text search (https://www.sqlite.org/fts3.html. Related: https://blogs.gnome.org/jnelson/)
- https://www.sqlite.org/undoredo.html
- http://www.sqlite.org/intern-v-extern-blob.html
- List of documentation keywords: https://swift.org/documentation/api-design-guidelines.html#special-instructions
- https://www.zetetic.net/sqlcipher/
- https://sqlite.org/sharedcache.html
- Amazing tip from Xcode labs: add a EXCLUDED_SOURCE_FILE_NAMES build setting to conditionally exclude sources for different configuration: https://twitter.com/zats/status/74386298602026496
- SQLITE_ENABLE_SQLLOG: http://mjtsai.com/blog/2016/07/19/sqlite_enable_sqllog/
- [Writing High-Performance Swift Code](https://github.com/apple/swift/blob/master/docs/OptimizationTips.rst)
- http://docs.diesel.rs/diesel/associations/index.html
- http://cocoamine.net/blog/2015/09/07/contentless-fts4-for-large-immutable-documents/
- https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-ios-10/1688
- pinyin: http://hustlzp.com/post/2016/02/ios-full-text-search-using-sqlite-fts4
- https://github.com/jflinter/Dwifft (FetchedRecordsController)
