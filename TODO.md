- [ ] Fix "More, when you're interested in specific table columns, you're out of luck, because databaseDidChange does not know about columns: it just knows that a row has been inserted, deleted, or updated, without further detail"
- [ ] Make public functions that return tables indexes
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

- [ ] Move Database Events filtering to the TransactionObserverType protocol
https://docs.djangoproject.com/en/1.9/ref/models/querysets/#order-by
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