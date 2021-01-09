## Cleanup

- [ ] SQLCipher: sqlite3_rekey is discouraged (https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320)
- [ ] Write regression tests for #156 and #157
- [ ] deprecate ScopeAdapter(base, scopes), because base.addingScopes has a better implementation
- [ ] https://github.com/groue/GRDB.swift/issues/514
- [ ] Test NOT TESTED methods


## Documentation

- [ ] Enhance the introduction to SQLRequest, based on the feedback in https://github.com/groue/GRDB.swift/issues/617
- [ ] Association: document how to use aggregates with inner join (testAnnotatedWithHasManyDefaultMaxJoiningRequired)


## Features

- [ ] Can we use generated columns to makes it convenient to index on inserted JSON objects? https://github.com/apple/swift-package-manager/pull/3090#issuecomment-740091760
- [ ] DatabaseMigrator.publisher(in:)
- [ ] Look at [@FetchRequest](https://developer.apple.com/documentation/swiftui/fetchrequest): managed object context is stored in the environment, and error processing happens somewhere else (where?).
- [ ] Handle SQLITE_LIMIT_VARIABLE_NUMBER in deleteAll(_:keys:) and similar APIs. https://www.sqlite.org/limits.html
- [ ] Concurrent migrator / or not
- [ ] Subqueries: request.isEmpty / request.exists
- [ ] Subqueries: request.count
- [ ] Extract one row from a hasMany association (the one with the maximum date, the one with a flag set, etc.) https://stackoverflow.com/questions/43188771/sqlite-join-query-most-recent-posts-by-each-user (failed PR: https://github.com/groue/GRDB.swift/pull/767)
- [ ] Turn a hasMany to hasOne without first/last : hasMany(Book.self).filter(Column("isBest") /* assume a single book is flagged best */).asOne()
- [ ] Support for more kinds of joins: https://github.com/groue/GRDB.swift/issues/740
- [ ] HasAndBelongsToMany: https://github.com/groue/GRDB.swift/issues/711
- [ ] Support UNION https://github.com/groue/GRDB.swift/issues/671
- [ ] Support Subqueries: WHERE EXISTS (SELECT ...)
- [ ] request.exists(db) as an alternative to fetchOne(db) != nil. Can generate optimized SQL.
- [ ] Measure the duration of transactions 
- [ ] Improve SQL generation for `Player.....fetchCount(db)`, especially with distinct. Try to avoid `SELECT COUNT(*) FROM (SELECT DISTINCT player.* ...)`
- [ ] Alternative technique for custom SQLite builds: see the Podfile at https://github.com/CocoaPods/CocoaPods/issues/9104, and https://github.com/clemensg/sqlite3pod
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
- [ ] More schema alterations
- [ ] DatabasePool.databaseSchemaIsLocked = true (should forbid schema changes, and never reset dbPool readers' caches). Or can we invalidate reader's cache automatically from the writer connection?
- [ ] Database.clearSchemaCache() is fine, but what about dbPool readers? Can we invalidate the cache for a whole pool?


## Unsure if necessary

- [ ] Have TableAlias embed the record type
- [ ] Have SQLPrimaryKeyExpression embed the record type
- [ ] Remove support for suspended databases - https://inessential.com/2020/02/13/how_we_fixed_the_dreaded_0xdead10cc_cras
- [ ] https://sqlite.org/pragma.html#pragma_index_xinfo
- [ ] Deprecate DatabaseQueue/Pool.addFunction, collation, tokenizer: those should be done in Configuration.prepareDatabase
- [ ] filter(rowid:), filter(rowids:)
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0075-import-test.md
- [ ] https://forums.swift.org/t/how-to-encode-objects-of-unknown-type/12253/6
- [ ] Configuration.crashOnError = true
- [ ] Glossary (Database Access Methods, etc.)
- [ ] Not sure: type safety for SQL expressions
    - [ ] Introduce some record protocol with an associated primary key type. Restrict filter(key:) methods to this type. Allow distinguishing FooId from BarId types.
    - [ ] Replace Column with TypedColumn. How to avoid code duplication (repeated types)? Keypaths?
- [ ] Cursor.underestimatedCount, which could speed up Array(cursor) and fetchAll()
- [ ] Remove prefix from association keys when association name is namespaced: https://github.com/groue/GRDB.swift/issues/584#issuecomment-517658122
- [ ] Alternative support for custom SQLite builds, wih CocoaPods: https://github.com/CocoaPods/CocoaPods/issues/9103


## Unsure how

- [ ] Association limits: `Author.including(optional: Author.books.order(date.desc).first)`
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
    
- [ ] new.updateChanges(from: old) vs. old.updateChanges(with: { old.a = new.a }). This is confusing.


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
- Realm oddity: http://stackoverflow.com/questions/41721769/realm-update-object-without-updating-lists
- File protection: https://github.com/ccgus/fmdb/issues/262
- File protection: https://lists.apple.com/archives/cocoa-dev/2012/Aug/msg00527.html
- [iOS apps are terminated every time they enter the background if they share an encrypted database with an app extension](https://github.com/sqlcipher/sqlcipher/issues/255)
- [Cross-Process notifications with CFNotificationCenterGetDarwinNotifyCenter](https://www.avanderlee.com/swift/core-data-app-extension-data-sharing/)
