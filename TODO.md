## Cleanup

- [ ] Deprecate DatabaseQueue/Pool.addFunction, collation, tokenizer: those should be done in Configuration.prepareDatabase
- [ ] SQLCipher: sqlite3_rekey is discouraged (https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320)
- [ ] Write regression tests for #156 and #157
- [ ] Fix matchingRowIds (todo: what is the problem, already?)
- [ ] deprecate ScopeAdapter(base, scopes), because base.addingScopes has a better implementation
- [ ] https://github.com/groue/GRDB.swift/issues/514
- [ ] Test NOT TESTED methods


## Features

- [ ] Attach databases. Interesting question: what happens when one attaches a non-WAL db to a databasePool?
- [ ] SQL Generation
    - [ ] date functions
    - [ ] NOW/CURRENT_TIMESTAMP
    - [ ] ROUND() http://marc.info/?l=sqlite-users&m=130419182719263
    - [ ] RANDOM() https://www.sqlite.org/lang_corefunc.html
    - [ ] GLOB https://www.sqlite.org/lang_expr.html
    - [ ] REGEXP https://www.sqlite.org/lang_expr.html
    - [ ] CASE x WHEN w1 THEN r1 WHEN w2 THEN r2 ELSE r3 END https://www.sqlite.org/lang_expr.html
- [ ] Allow concurrent reads from a snapshot
- [ ] Decode NSDecimalNumber from text database values
- [ ] Check https://sqlite.org/sqlar.html
- [ ] FTS: prefix queries
- [ ] A way to stop a ValueObservation observer without waiting for deinit
- [ ] More schema alterations
- [ ] Query interface updates. One use case for query interface updates that is uneasy to deal with raw SQL:
    
    ```swift
    // Uneasy to do with raw SQL
    let players = Player.filter(...) // Returns a request that filters on column A or column B depending on the argument
    players.update(...)              // Runs the expected UPDATE statement
    ```


## Unsure if necessary

- [ ] filter(rowid:), filter(rowids:)
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0075-import-test.md
- [ ] https://forums.swift.org/t/how-to-encode-objects-of-unknown-type/12253/6
- [ ] Configuration.crashOnError = true
- [ ] Glossary (Database Access Methods, etc.)
- [ ] ValueObservation.flatMap. Not sure it is still useful now that we have ValueObservation.tracking(value:)
- [ ] rename fetchOne to fetchFirst. Not sure because it is a big breaking change. Not sure because ValueObservation.tracking(value:) has reduced the need for observationForFirst.
- [ ] Not sure: type safety for SQL expressions
    - [ ] Introduce some record protocol with an associated primary key type. Restrict filter(key:) methods to this type. Allow distinguishing FooId from BarId types.
    - [ ] Replace Column with TypedColumn. How to avoid code duplication (repeated types)? Keypaths?
- [ ] Cursor.underestimatedCount, which could speed up Array(cursor) and fetchAll()
- [ ] Remove prefix from association keys when association name is namespaced: https://github.com/groue/GRDB.swift/issues/584#issuecomment-517658122


## Unsure how

- [ ] Joins and full-text tables
- [ ] UPSERT https://www.sqlite.org/lang_UPSERT.html
- [ ] Support for "INSERT INTO ... SELECT ...".
- [ ] Look at the jazzy configuration of https://github.com/bignerdranch/Deferred
- [ ] Predicates, so that a filter can be evaluated both on the database, and on a record instance.
    
    After investigation, we can't do it reliably without knowing the collation used by a column. And SQLite does not provide this information elsewhere than in the full CREATE TABLE statement stored in sqlite_master.
- [ ] ValueObservation erasure

    ```
    // Do better than this
    observation.mapReducer { _, reducer in AnyValueReducer(reducer) }
    ```
    
- [ ] FetchedRecordsController diff algorithm: check https://github.com/RxSwiftCommunity/RxDataSources/issues/256
- [ ] new.updateChanges(from: old) vs. old.updateChanges(with: { old.a = new.a }). This is confusing.
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


## Reading list

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
