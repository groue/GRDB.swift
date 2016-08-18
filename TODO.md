- [ ] Joins: why do we write A.filter { $0["name"] == "foo" } instead of A.filter { $0.value(named: "name") == "foo" }
    - [ ] We'd thus also need A.filter { $0.value(nameColumn) == "foo" }
    - [?] We'd thus also need A.filter { $0.value(atIndex: 0) == "foo" }
    - [X] We'd thus also need Row.value(nameColumn)
- [ ] Joins: see "Self Join / Tree example" in http://greenrobot.org/greendao/documentation/joins/
– [ ] Joins: allow to give an alias, so that one can use an alias in an explicit SQL snippet
    - [X] Person.include(Person.birthCountry.aliased("customCountryAlias"))
    - [ ] Person.aliased("customPersonAlias").include(Person.birthCountry)
- [ ] Join annotations: min, max, average
- [ ] Join annotations: multiple annotations
- [ ] Join annotations: expressions like count(relation) + 1
- [ ] Joins: support for "through" relations, and especially have include/join methods apply to the target table, not the inner table. See also consequences on the required modifier.
- [ ] Joins: the more I look at it, the more I think `A.join(r1.include(r2))` should not include r2 columns. After all, it reads `A.join(...)` and thus looks like it does not extend the selection.
- [ ] Joins: Add fetchOne(key:), fetchAll(keys:), and fetch(keys:) to all requests. Goal: `Book.include(author).fetchOne(key: 1)`

- [ ] @hdlj: Extensibility of the Query Interface
- [ ] @hdlj: FetchedRecordsController throttling
- [ ] @hdlj: Check RAM pressure
- [ ] DatabasePool: attempt to read from the database in DatabasePool.init(). Don't crash, but throw eventual error instead. (Related issue: https://github.com/groue/GRDB.swift/issues/99)
- [ ] Test Row(SQLColumn)
- [ ] Persistable partial update: allow models whose persistentDictionary only contains a subset of table columns (and count of default value)
- [ ] What is the behavior inTransaction and inSavepoint behaviors in case of commit error? Code looks like we do not rollback, leaving the app in a weird state (out of Swift transaction block with a SQLite transaction that may still be opened).
- [ ] GRDBCipher: remove limitations on iOS or OS X versions
- [ ] FetchedRecordsController: take inspiration from https://github.com/jflinter/Dwifft
- [ ] File protection: Read https://github.com/ccgus/fmdb/issues/262 and understand https://lists.apple.com/archives/cocoa-dev/2012/Aug/msg00527.html
- [ ] Support for resource values (see https://developer.apple.com/library/ios/qa/qa1719/_index.html)
- [ ] DOC: Since commit e6010e334abdf98eb9f62c1d6abbb2a9e8cd7d19, one can not use the raw SQLite API without importing the SQLite module for the platform. We need to document that.
- [ ] Query builder
    - [ ] SELECT readers.*, books.* FROM ... JOIN ...
    - [ ] date functions
    - [ ] NOW
    - [ ] RANDOM() https://www.sqlite.org/lang_corefunc.html
    - [ ] LIKE https://www.sqlite.org/lang_expr.html
    - [ ] GLOB https://www.sqlite.org/lang_expr.html
    - [ ] MATCH https://www.sqlite.org/lang_expr.html
    - [ ] REGEXP https://www.sqlite.org/lang_expr.html
    - [ ] CASE x WHEN w1 THEN r1 WHEN w2 THEN r2 ELSE r3 END https://www.sqlite.org/lang_expr.html
- [ ] In-memory DatabasePool (https://www.sqlite.org/inmemorydb.html). Unfortunately, a shared cache is not enough. Since SQLite does not provide WAL mode for in-memory databases, it's easy to get "database is locked" errors. A WAL database on a RAM disk looks out of reach. Possible solution: have one writer that is exclusive with the readers.


Not sure

- [ ] row.value(SQLColumn)
- [X] Have Row adopt LiteralDictionaryConvertible
    - [ ] ... allowing non unique column names
- [ ] Remove DatabaseValue.value()
    - [X] Don't talk about DatabaseValue.value() in README.md
- [ ] Move Database Events filtering to the TransactionObserverType protocol
- [ ] Support for NSColor/UIColor. Beware UIColor components can go beyond [0, 1.0] in iOS10.


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