- [ ] Attach databases. Interesting question: what happens when one attaches a non-WAL db to a databasePool?
- [ ] SQLCipher: sqlite3_rekey is discouraged (https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320)
- [ ] Query builder
    - [ ] date functions
    - [ ] NOW/CURRENT_TIMESTAMP
    - [ ] ROUND() http://marc.info/?l=sqlite-users&m=130419182719263
    - [ ] RANDOM() https://www.sqlite.org/lang_corefunc.html
    - [ ] GLOB https://www.sqlite.org/lang_expr.html
    - [ ] REGEXP https://www.sqlite.org/lang_expr.html
    - [ ] CASE x WHEN w1 THEN r1 WHEN w2 THEN r2 ELSE r3 END https://www.sqlite.org/lang_expr.html
- [ ] Write regression tests for #156 and #157
- [ ] Allow concurrent reads from a snapshot
- [ ] Decode NSDecimalNumber from text database values
- [ ] Check https://sqlite.org/sqlar.html
- [ ] filter(rowid:), filter(rowids:)
- [ ] Fix matchingRowIds
- [ ] Simplify Range extensions for Swift 4.1
- [ ] https://forums.swift.org/t/how-to-encode-objects-of-unknown-type/12253/6
- [ ] deprecate ScopeAdapter(base, scopes), because base.addingScopes has a better implementation
- [ ] Joins and full-text tables
- [ ] UPSERT https://www.sqlite.org/lang_UPSERT.html
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0075-import-test.md
- [ ] Avoid code duplication: https://forums.swift.org/t/c-interoperability-combinations-of-library-and-os-versions/14029/4
- [ ] Allow joining methods on DerivableRequest
- [ ] DatabaseWriter.assertWriteAccess()
- [ ] Configuration.crashOnError = true
- [ ] Support for "INSERT INTO ... SELECT ...". For example:
    
    ```swift
    // INSERT INTO rigth (id, name) SELECT id, name FROM left
    let lefts = Left.select(Left.Columns.id, Left.Columns.name)
    try Right.insert(lefts)
    ```
- [ ] select values from a JSON column:
    
    ```swift
    let nesteds = try Record
        .select(Column("nested"), as: Nested.self)
        .fetchAll(db)
    ```
- [ ] Consider renaming dbQueue.inDatabase, dbPool.writeWithoutTransaction -> dbQueue/Pool.exclusive
- [ ] FetchedRecordsController diff algorithm: check https://github.com/RxSwiftCommunity/RxDataSources/issues/256

Swift 4.2

- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0210-key-path-offset.md
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0208-package-manager-system-library-targets.md
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0207-containsOnly.md
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0206-hashable-enhancements.md
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0202-random-unification.md
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0201-package-manager-local-dependencies.md
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0193-cross-module-inlining-and-specialization.md

Not sure

- [ ] HiddenColumnsAdapter
- [ ] Not sure: type safety for SQL expressions
    - [ ] Introduce some record protocol with an associated primary key type. Restrict filter(key:) methods to this type. Allow distinguishing FooId from BarId types.
    - [ ] Replace Column with TypedColumn. How to avoid code duplication (repeated types)? Keypaths?
- [ ] Encode/decode nested records/arrays/dictionaries as JSON?
- [ ] Cursor.underestimatedCount, which could speed up Array(cursor) and fetchAll()
- [ ] Support for OR ROLLBACK, and mismatch between the Swift depth and the SQLite depth of nested transactions/savepoint:
    
    ```swift
    try db.inTransaction {           // Swift depth: 1, SQLite depth: 1
        try db.execute("COMMIT")     // Swift depth: 1, SQLite depth: 0
        try db.execute("INSERT ...") // Should throw an error since this statement is no longer protected by a transaction
        try db.execute("SELECT ...") // Should throw an error since this statement is no longer protected by a transaction
        return .commit 
    }
    ```

    ```swift
    try db.inTransaction {
        try db.execute("INSERT OR ROLLBACK ...") // throws 
        return .commit // not executed because of error
    }   // Should not ROLLBACK since transaction has already been rollbacked
    ```

    ```swift
    try db.inTransaction {
        do {
            try db.execute("INSERT OR ROLLBACK ...") // throws
        } catch {
        }
        try db.execute("INSERT ...") // Should throw an error since this statement is no longer protected by a transaction
        try db.execute("SELECT ...") // Should throw an error since this statement is no longer protected by a transaction
        return .commit
    }
    ```

    ```swift
    try db.inTransaction {
        do {
            try db.execute("INSERT OR ROLLBACK ...") // throws
        } catch {
        }
        return .commit  // Should throw an error since transaction has been rollbacked and user's intent can not be applied
    }
    ```


Requires recompilation of SQLite:

- [ ] https://www.sqlite.org/c3ref/column_database_name.html could help extracting out of a row a subrow only made of columns that come from a specific table. Requires SQLITE_ENABLE_COLUMN_METADATA which is not set on the sqlite3 lib that ships with OSX.



Reading list:

- Documentation generation: https://twitter.com/jckarter/status/987525569196650496: cmark is the implementation the Swift compiler uses for doc comments etc.
- VACUUM (https://blogs.gnome.org/jnelson/)
- http://www.sqlite.org/intern-v-extern-blob.html
- https://sqlite.org/sharedcache.html
- Undo: https://www.sqlite.org/undoredo.html
- Undo: https://sqlite.org/sessionintro.html
- Swift, Xcode:List of Swift documentation keywords: https://swift.org/documentation/api-design-guidelines.html#special-instructions
- Swift, Xcode:Amazing tip from Xcode labs: add a EXCLUDED_SOURCE_FILE_NAMES build setting to conditionally exclude sources for different configuration: https://twitter.com/zats/status/74386298602026496
- SQLITE_ENABLE_SQLLOG: http://mjtsai.com/blog/2016/07/19/sqlite_enable_sqllog/
- Swift, Xcode: https://github.com/apple/swift/blob/master/docs/OptimizationTips.rst
- Associations: http://docs.diesel.rs/diesel/associations/index.html
- FTS: http://cocoamine.net/blog/2015/09/07/contentless-fts4-for-large-immutable-documents/
- pinyin: http://hustlzp.com/post/2016/02/ios-full-text-search-using-sqlite-fts4
- FetchedRecordsController: https://github.com/jflinter/Dwifft
- FetchedRecordsController: https://github.com/wokalski/Diff.swift (Faster)
- FetchedRecordsController: https://github.com/andre-alves/PHDiff
- React oddity: http://stackoverflow.com/questions/41721769/realm-update-object-without-updating-lists
- File protection: https://github.com/ccgus/fmdb/issues/262
- File protection: https://lists.apple.com/archives/cocoa-dev/2012/Aug/msg00527.html
- [iOS apps are terminated every time they enter the background if they share an encrypted database with an app extension](https://github.com/sqlcipher/sqlcipher/issues/255)
