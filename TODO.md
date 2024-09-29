## Cleanup

- [ ] Schemas and attached databases: can we enhance our pragma handling from https://sqlite.org/forum/forumpost/27f85a4634
- [ ] SQLCipher: sqlite3_rekey is discouraged (https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320)
- [ ] Write regression tests for #156 and #157
- [ ] deprecate ScopeAdapter(base, scopes), because base.addingScopes has a better implementation
- [ ] https://github.com/groue/GRDB.swift/issues/514
- [ ] Test NOT TESTED methods
- [ ] Get inspiration from the templates at https://github.com/woocommerce/woocommerce-ios/tree/develop/.github (https://github.com/woocommerce/woocommerce-ios/pull/3523)

## Documentation

- [ ] Enhance the introduction to SQLRequest, based on the feedback in https://github.com/groue/GRDB.swift/issues/617
- [ ] Association: document how to use aggregates with inner join (testAnnotatedWithHasManyDefaultMaxJoiningRequired)
- [ ] Should we document that `PRAGMA locking_mode = EXCLUSIVE` improves performances? https://sqlite.org/forum/forumpost/866bf3407a


## Features

- [ ] Detect when `ColumnExpression.noOverwrite` excludes a non-existing column. Code is in DOA.upsertStatement()`. We should not silently ignore non-existing columns, as demonstrated by <https://github.com/groue/GRDB.swift/issues/1539>.  
- [ ] Can Swift 5.5 help us with `select(.all)` (request of RowDecoder), `select(.id)` (request of RowDecoder.ID), `select(.rowid)` (request of Int64)?
- [ ] Direct access to statement for bindings
- [ ] Property wrapper that decodes dictionaries (but how to tell the key column?)
- [X] See if SQLITE_FCNTL_DATA_VERSION could help working around the lack of snapshots in order to avoid double initial fetch of ValueObservation. Result: no, it does not look it returns values that are comparable between two distinct SQLite connections (from the initial reader, and from the writer thhat starts the observation)
- [X] Grab all FTS tokens in a string
- [NO] Can we generate EXISTS with association? `Team.annotated(with: Team.players.exists)`
    No. We already have `Team.annotated(with: Team.players.isEmpty == false)`.
    It does not use an EXISTS expression, but a JOIN, and this is better for
    the internal consistency of the query interface, and the rules that deal
    with association keys.
- [X] GRDB 6: have DatabaseRegionObservation produce DatabaseCancellable just as ValueObservation.
- [X] RangeReplaceableCollection should have append(contentsOf: cursor)
- [ ] GRDB 6: choose persistence table
- [ ] GRDB 6: decoding errors
    - [X] throwing FetchableRecord initializer FIRST
    - [X] throwing Decodable FetchableRecord initializer SECOND
    - [X] deal with as much value decoding error as possible
    - [?] expose throwing row accessors
- [ ] GRDB 6: Batch insert & Batch insert RETURNING - https://stackoverflow.com/questions/1609637/is-it-possible-to-insert-multiple-rows-at-a-time-in-an-sqlite-database 
- [ ] GRDB 6: INSERT or UPDATE columns to their default value 
- [X] GRDB 6: afterNextTransactionCommit -> afterNextTransaction(onCommit:onRollback:)  
- [ ] GRDB 6: encoding errors for record (`EncodableRecord.encode(to:)`)
    - [X] throwing EncodableRecord.encode FIRST
- [?] GRDB 6: protocol-based record container? This could avoid computing & encoding values we do not need. 
- [ ] GRDB 6: encoding & statement binding errors for database values (conversion to DatabaseValue, statement binding, etc)
    - [ ] Prevent Date > 9999 from being encoded
- [X] GRDB 6: Swift 5.7
- [X] GRDB 6: any / some
- [X] GRDB 6: primary associated types (cursor, requests, ...)
- [X] GRDB 6: remove existential/generic duplicated methods
- [ ] GRDB 6: remove useless AnyXXX Type erasers
- [X] GRDB 6: conflict resolution in persistence methods
- [X] GRDB 6: UPSERT
- [X] GRDB 6: support for RETURNING
    - [X] Support for default values: `Player.insert(db, as: FullPlayer.self)`
- [?] GRDB 6: allow mutating `update` (for timestamps)
- [?] GRDB 6: let record choose persistence table (insert(into:) ?)
- [?] GRDB 6: Support opaque return types (macOS Catalina, iOS 13, tvOS 13, watchOS 6 and later: https://stackoverflow.com/questions/56518406)
- [ ] Long run edition. Use case: user edits the database (CRUD) but the application wants to commit and the end of the editing session.
    * Create an edition SQLite connection with an open transaction (a new kind of DatabaseWriter with a save() method)
    * All other writes will fail with SQLITE_BUSY. Unless they are schedules in a target dispatch queue which is paused during the edition.
- [ ] Can we use generated columns to makes it convenient to index on inserted JSON objects? https://github.com/apple/swift-package-manager/pull/3090#issuecomment-740091760
- [ ] Look at [@FetchRequest](https://developer.apple.com/documentation/swiftui/fetchrequest): managed object context is stored in the environment, and error processing happens somewhere else (where?).
- [ ] Handle SQLITE_LIMIT_VARIABLE_NUMBER in deleteAll(_:keys:) and similar APIs. https://www.sqlite.org/limits.html
- [X] Subqueries: ~request.isEmpty~ / [X] request.exists()
- [ ] Subqueries: request.count
- [ ] Extract one row from a hasMany association (the one with the maximum date, the one with a flag set, etc.) https://stackoverflow.com/questions/43188771/sqlite-join-query-most-recent-posts-by-each-user (failed PR: https://github.com/groue/GRDB.swift/pull/767)
- [ ] Turn a hasMany to hasOne without first/last : hasMany(Book.self).filter(Column("isBest") /* assume a single book is flagged best */).asOne()
- [ ] Support for more kinds of joins: https://github.com/groue/GRDB.swift/issues/740
- [ ] HasAndBelongsToMany: https://github.com/groue/GRDB.swift/issues/711
- [ ] Support UNION https://github.com/groue/GRDB.swift/issues/671 (https://www.sqlite.org/lang_select.html#compound)
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
- [ ] Check https://sqlite.org/sqlar.html
- [ ] More schema alterations
- [ ] Database.clearSchemaCache() is fine, but what about dbPool readers? Can we invalidate the cache for a whole pool?
- [ ] What can we do with `cross-module-optimization`? See https://github.com/apple/swift-homomorphic-encryption

- [X] GRDB7/BREAKING: insertAndFetch, saveAndFetch, and updateAndFetch no longer return optionals (32f41472)
- [X] GRDB7/BREAKING: AsyncValueObservation does not need any scheduler (83c0e643)
- [X] GRDB7/BREAKING: Stop exporting SQLite (679d6463)
- [X] GRDB7/BREAKING: Remove Configuration.defaultTransactionKind (2661ff46)
- [X] GRDB7: Replace LockedBox with Mutex (00ccab06)
- [X] GRDB7: Sendable: BusyCallback (e0d8e20b)
- [X] GRDB7: Sendable: BusyMode (e0d8e20b)
- [X] GRDB7: Sendable: TransactionClock (f7dc72a5)
- [X] GRDB7: Sendable: Configuration (54ffb21f)
- [X] GRDB7: Sendable: DatabaseDataEncodingStrategy (264d7fb5)
- [X] GRDB7: Sendable: DatabaseDateEncodingStrategy (264d7fb5)
- [X] GRDB7: Sendable: DatabaseColumnEncodingStrategy (264d7fb5)
- [X] GRDB7: Sendable: DatabaseDataDecodingStrategy (264d7fb5)
- [X] GRDB7: Sendable: DatabaseDateDecodingStrategy (264d7fb5)
- [X] GRDB7: Sendable: DatabaseColumnDecodingStrategy (264d7fb5)
- [X] GRDB7/BREAKING: Remove DatabaseFuture and concurrentRead (05f7d3c8)
- [X] GRDB7: Sendable: DatabaseFunction (6e691fe7)
- [X] GRDB7: Sendable: DatabaseMigrator (22114ad4)
- [X] GRDB7: Not Sendable: FilterCursor (b26e9709)
- [X] GRDB7: Sendable: RowAdapter (d138af26)
- [X] GRDB7: Sendable: ValueObservationScheduler (8429eb68)
- [X] GRDB7: Sendable: DatabaseCollation (4d9d67dd)
- [X] GRDB7: Sendable: LogErrorFunction (f362518d)
- [X] GRDB7: Sendable: ReadWriteBox (57a86a0e)
- [X] GRDB7: Sendable: Pool (f13b2d2e)
- [X] GRDB7: Sendable: OnDemandFuture fulfill (2aabc4c1)
- [X] GRDB7: Sendable: WALSnapshotTransaction (7fd34012)
- [-] GRDB7: sending closures for SerializedDatabase
- [-] GRDB7: sending closures for ValueObservationScheduler
- [X] GRDB7: Sendable closures for ValueObservation.handleEvents
- [X] GRDB7: Not Sendable: Record (make it explicit if subclasses can be made sendable)
- [ ] GRDB7: Not Sendable: databasepublishers/databaseregion, migrate, read, value, write
- [X] GRDB7: Sendable closures for writePublisher
- [X] GRDB7: Sendable closures for readPublisher
- [-] GRDB7: Not Sendable: fts5customtokenizer, fts5tokenizer, fts5wrappertokenizer
- [X] GRDB7: Sendable: DatabasePromise (05899228, 5a2c15b8)
- [X] GRDB7: Sendable: TableAlias (f2b0b186)
- [X] GRDB7: Sendable: SQLRelation (9545bf70)
- [X] GRDB7: Sendable: SQL (ac33856f)
- [ ] GRDB7: Split Row.swift (2ce8a619)
- [X] GRDB7: Cleanup ValueReducer (6c73b1c5)
- [X] GRDB7: DatabaseCursor has a primary associated type (b11c5dd2)
- [ ] GRDB7: Enable Strict Concurrency Checks (6aa43ded)
- [X] GRDB7: Sendable: OrderedDictionary (e022c35b)
- [X] GRDB7: Rename ReadWriteBox to ReadWriteLock (7f5205ef)
- [X] GRDB7: Sendable: DatabaseRegionConvertible (b4677ded)
- [X] GRDB7: Sendable: ValueConcurrentObserver (87b9db65, 5465d056)
- [X] GRDB7: Sendable: ValueWriteOnlyObserver (ff2a7548)
- [X] GRDB7: Sendable: DatabaseCancellable (2f93f00b, 8f486a5e)
- [X] GRDB7: ValueObservation closures
- [?] GRDB7: DatabasePublishers.ValueSubscription
- [X] GRDB7: Sendable: ValueObservation (93f6f982)
- [?] GRDB7: Not Sendable: SharedValueObservation
- [X] GRDB7: doc (c0838cf9)
- [X] GRDB7/BREAKING: PersistenceContainer is Sendable (50eefa8c)
- [X] GRDB7: TableRecord.databaseSelection must be declared as a computed property (24d232aa)
    - [X] Doc
    - [X] Migration Guide
- [X] GRDB7: Sendable: Association (b06aaee4)
- [ ] GRDB7/Tests: Sendable: ValueObservationRecorder (2947b3d7)
- [X] GRDB7: ValueObservation.print cautiously uses its stream argument (5f8b39b7)
- [ ] GRDB7/Tests: use a single and Sendable test TextOutputStream (bbb1a736)
- [X] GRDB7: ValueObservation needs a ValueReducer, not a `_ValueReducer` (08733108)
- [X] GRDB7: Database support for cancellation (4ddf4bca)
- [X] GRDB7: SerializedDatabase support for async db access with support for Task cancellation (737cb149)
- [X] GRDB7: DatabaseWriter async methods support Task cancellation (a5226501)
- [X] GRDB7: DatabaseReader async methods support Task cancellation (10c9d311)
- [X] GRDB7: Document that async methods can throw CancellationError (8df18fb8)
- [-] GRDB7: Sendable: AssociationAggregate (48ad10ae)
- [X] GRDB7: Sendable: AsyncValueObservation (necessary for async algorithm) (ce63cdfa)
- [X] GRDB7: Sendable: DatabaseRegionObservation (b4ff52fb)
- [-] GRDB7: DispatchQueue.asyncSending (7b075e6b)
- [X] GRDB7: Replace sequences with collection (e.g. https://github.com/tidal-music/tidal-sdk-ios/pull/39)
- [X] GRDB7: Replace `some` DatabaseReader/Writer with `any` where possible, in order to avoid issues with accessing DatabaseContext from GRDBQuery (if the problem exists in Xcode 16)
- [X] GRDB7: bump to iOS 13, macOS 10.15, tvOS 13 (for ValueObservation support for MainActor)

- [ ] GRDB7: DatabasePublishers.Value should carry the type of the Scheduler, so that we can rely on main-actor-isolated callbacks.
- [X] GRDB7: Remove warning about "products" in Package.swift
- [X] GRDB7: Fixits
    - [X] defaultTransactionKind
    - [X] concurrentRead
- [X] GRDB7: Swift Concurrency recommendations
    - [X] Record classe(s)
    - [X] InferSendableFromCaptures
- [X] GRDB7: stop fostering the Record class
    - Remove all mentions from the README
    - Warn about it in the documentation of the class.
- [X] GRDB7: Breaking changes documentation
    - [X] [BREAKING] Xcode 16+, Swift 6+
    - [X] [BREAKING] iOS 13+
    - [X] [BREAKING] macOS 10.15+
    - [X] [BREAKING] tvOS 13+
    - [X] [BREAKING] watchOS 7+
    - [-] insertAndFetch, updateAndFetch, saveAndFetch
    - [X] CSQLite renamed to GRDBCSQLite
    - [X] CSQLite is not exported
    - [X] defaultTransactionKind
    - [X] concurrentRead
    - [X] record column strategies:
        - databaseDataEncodingStrategy
        - databaseDateEncodingStrategy
        - databaseUUIDEncodingStrategy
        - databaseDataDecodingStrategy
        - databaseDateDecodingStrategy
    - [X] PersistenceContainer subscript no longer returns its input value
    - [X] cancellation of async database access
    - [X] Async sequences built from ValueObservation schedule values and errors on the cooperative thread pool by default.
    - [X] `TableRecord.databaseSelection` should be declared as a computed static property
    - [-] databaseDecodingUserInfo and databaseEncodingUserInfo must be declared as a computed property
- [ ] GRDB7: Review experimental apis
- [?] GRDB7: Change ValueObservation callback argument so that it could expose snapshots? https://github.com/groue/GRDB.swift/discussions/1523#discussioncomment-9092500 

## Unsure if necessary

- [ ] Have TableAlias embed the record type
- [ ] Have SQLPrimaryKeyExpression embed the record type
- [ ] Remove support for suspended databases - https://inessential.com/2020/02/13/how_we_fixed_the_dreaded_0xdead10cc_cras
- [ ] https://sqlite.org/pragma.html#pragma_index_xinfo
- [ ] filter(rowid:), filter(rowids:)
- [ ] https://github.com/apple/swift-evolution/blob/master/proposals/0075-import-test.md
- [ ] https://forums.swift.org/t/how-to-encode-objects-of-unknown-type/12253/6
- [ ] Configuration.crashOnError = true
- [ ] Glossary (Database Access Methods, etc.)
- [ ] Not sure: type safety for SQL expressions
    - [ ] Introduce some record protocol with an associated primary key type. Restrict filter(key:) methods to this type. Allow distinguishing FooId from BarId types.
    - [ ] Replace Column with TypedColumn. How to avoid code duplication (repeated types)? Keypaths?
- [ ] Remove prefix from association keys when association name is namespaced: https://github.com/groue/GRDB.swift/issues/584#issuecomment-517658122
- [ ] Alternative support for custom SQLite builds, with CocoaPods: https://github.com/CocoaPods/CocoaPods/issues/9103


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
