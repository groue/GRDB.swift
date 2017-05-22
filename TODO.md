- [ ] We share the database cache between database pool writers and readers. But what if a writer modifies the database schema within a transaction, and a concurrent reader reads the cache? Bad things, isn't it? Write failing tests first, and fix the bug.
- [ ] Attach databases. Interesting question: what happens when one attaches a non-WAL db to a databasePool?
- [ ] SQLCipher: sqlite3_rekey is discouraged (https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320)
- [ ] What is the behavior inTransaction and inSavepoint behaviors in case of commit error? Code looks like we do not rollback, leaving the app in a weird state (out of Swift transaction block with a SQLite transaction that may still be opened).
- [ ] Query builder
    - [ ] SELECT readers.*, books.* FROM ... JOIN ...
    - [ ] date functions
    - [ ] NOW/CURRENT_TIMESTAMP
    - [ ] ROUND() http://marc.info/?l=sqlite-users&m=130419182719263
    - [ ] RANDOM() https://www.sqlite.org/lang_corefunc.html
    - [ ] GLOB https://www.sqlite.org/lang_expr.html
    - [ ] REGEXP https://www.sqlite.org/lang_expr.html
    - [ ] CASE x WHEN w1 THEN r1 WHEN w2 THEN r2 ELSE r3 END https://www.sqlite.org/lang_expr.html
- [ ] See how we can use [sqlite3_get_autocommit](https://www.sqlite.org/capi3ref.html#sqlite3_get_autocommit)

v1.0 checklit

- [X] Remove RowConvertible.awakeFromFetch()
- [ ] Document or remove DatabaseCoder
- [X] Check scenarios where cached statements aren't performed with the arguments expected by the user (1. produce a cached statement, with some arguments 2. produce the same cached statement, with different arguments 3. run the first statement (with wrong arguments)). Provide eventual fix.
- [ ] Support [joins](https://github.com/groue/GRDB.swift/issues/176)
- [ ] Request/TypedRequest:
    - [X] Why Request/TypedRequest? What about removing TypedRequest and having a Fetched associated type in Request?
        We keep TypedRequest because adding an associate Fetched type to Request forces too many APIs to become generic for no real purpose, when one does not use AnyRequest<Void> as a concrete type.
        Besides, not all requests have a naturel Fetched type: request.fetchCount(db) doesn't care about the type of the request, for example.   
    - [X] Question AnyRequest and AnyTypedRequest as results (for example, `SQLRequest("...").bound(to: MyRecord.self)` returns AnyTypedRequest).
        It's not worth the effort to introduce more concrete request types (AdaptedRequest, AdaptedTypedRequest, BoundRequest)
    - [X] Question the naming of the `request.bound(to:T.self)` method. Prefer... `request..asRequest(of: T.self)`
- [ ] Make GRDB less stringly-typed. When a user defines a static list of columns for a record type, those columns should be easier to use:
    - [ ] Persistable.persistentDictionary requires string keys, doesn't accept columns
    - [ ] If possible, improve on `Person.filter(Person.email != nil)` or `Person.filter(Person.Column.email != nil)` (see [#186](https://github.com/groue/GRDB.swift/issues/186))
    - [ ] Check [SE-0166](https://github.com/apple/swift-evolution/blob/master/proposals/0166-swift-archival-serialization.md)

Not sure

- [ ] Support for resource values (see https://developer.apple.com/library/ios/qa/qa1719/_index.html)
- [ ] Think about supporting Cursor's underestimatedCount, which could speed up Array(cursor) and fetchAll()
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

- [ ] Support for NSColor/UIColor. Beware UIColor components can go beyond [0, 1.0] in iOS10.
- [ ] Store dates as timestamp (https://twitter.com/gloparco/status/780948021613912064, https://github.com/groue/GRDB.swift/issues/97)


Require changes in the Swift language:

- [ ] Specific and optimized Optional<StatementColumnConvertible>.fetch... methods when http://openradar.appspot.com/22852669 is fixed.


Requires recompilation of SQLite:

- [ ] https://www.sqlite.org/c3ref/column_database_name.html could help extracting out of a row a subrow only made of columns that come from a specific table. Requires SQLITE_ENABLE_COLUMN_METADATA which is not set on the sqlite3 lib that ships with OSX.



Reading list:

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
