Full-Text Search
================

**Full-Text Search is an efficient way to search a corpus of textual documents.**

```swift
// Create full-text tables
try db.create(virtualTable: "book", using: FTS4()) { t in // or FTS3(), or FTS5()
    t.column("author")
    t.column("title")
    t.column("body")
}

// Populate full-text table with records or SQL
try Book(...).insert(db)
try db.execute(
    sql: "INSERT INTO book (author, title, body) VALUES (?, ?, ?)",
    arguments: [...])

// Build search patterns
let pattern = FTS3Pattern(matchingPhrase: "Moby-Dick")

// Search with the query interface or SQL
let books = try Book.matching(pattern).fetchAll(db)
let books = try Book.fetchAll(db,
    sql: "SELECT * FROM book WHERE book MATCH ?",
    arguments: [pattern])
```

- **[Choosing the Full-Text Engine](#choosing-the-full-text-engine)**
- **[Enabling FTS5 Support](#enabling-fts5-support)**
- **Create Full-Text Virtual Tables**: [FTS3/4](#create-fts3-and-fts4-virtual-tables), [FTS5](#create-fts5-virtual-tables)
- **Choosing a Tokenizer**: [FTS3/4](#fts3-and-fts4-tokenizers), [FTS5](#fts5-tokenizers)
- **Tokenization**: [FTS3/4](#fts3-and-fts4-tokenization), [FTS5](#fts5-tokenization)
- **Search Patterns**: [FTS3/4](#fts3pattern), [FTS5](#fts5pattern)
- **Sorting by Relevance**: [FTS5](#fts5-sorting-by-relevance)
- **External Content Full-Text Tables**: [FTS4/5](#external-content-full-text-tables)
- **Full-Text Record**s: [FTS3/4/5](#full-text-records)
- **Unicode Full-Text Gotchas**: [FTS3/4/5](#unicode-full-text-gotchas). Unicorns don't exist.
- **Custom Tokenizers**: [FTS5](FTS5Tokenizers.md). Leverage extra full-text features such as synonyms or stop words. Avoid [unicode gotchas](#unicode-full-text-gotchas).
- **Sample Code**: [WWDC Companion](https://github.com/groue/WWDCCompanion), an iOS app that stores, displays, and lets the user search the WWDC 2016 sessions.


## Choosing the Full-Text Engine

**SQLite supports three full-text engines: [FTS3, FTS4](https://www.sqlite.org/fts3.html) and [FTS5](https://www.sqlite.org/fts5.html).**

Generally speaking, FTS5 is better than FTS4 which improves on FTS3. But this does not really tell which engine to choose for your application. Instead, make your choice depend on:

- **The full-text features needed by the application**:
    
    | Full-Text Needs                                                            | FTS3 | FTS4 | FTS5 |
    | -------------------------------------------------------------------------- | :--: | :--: | :--: |
    | :question: Queries                                                         |      |      |      |
    | **Words searches** (documents that contain "database")                     |  X   |  X   |  X   |
    | **Prefix searches** (documents that contain a word starting with "data")   |  X   |  X   |  X   |
    | **Phrases searches** (documents that contain the phrase "SQLite database") |  X   |  X   |  X   |
    | **Boolean searches** (documents that contain "SQLite" or "database")       |  X   |  X   |  X   |
    | **Proximity search** (documents that contain "SQLite" near "database")     |  X   |  X   |  X   |
    | :scissors: Tokenization                                                    |      |      |      |
    | **Ascii case insensitivity** (have "DATABASE" match "database")            |  X   |  X   |  X   |
    | **Unicode case insensitivity** (have "ÉLÉGANCE" match "élégance")          |  X   |  X   |  X   |
    | **Latin diacritics insensitivity** (have "elegance" match "élégance")      |  X   |  X   |  X   |
    | **English Stemming** (have "frustration" match "frustrated")               |  X   |  X   |  X   |
    | **English Stemming and Ascii case insensitivity**                          |  X   |  X   |  X   |
    | **English Stemming and Unicode case insensitivity**                        |      |      |  X   |
    | **English Stemming and Latin diacritics insensitivity**                    |      |      |  X   |
    | **Synonyms** (have "1st" match "first")                                    |  ¹   |  ¹   | X ²  |
    | **Pinyin and Romaji** (have "romaji" match "ローマ字")                         |  ¹   |  ¹   | X ²  |
    | **Stop words** (don't index, and don't match words like "and" and "the")   |  ¹   |  ¹   | X ²  |
    | **Spell checking** (have "alamaba" match "alabama")                        |  ¹   |  ¹   |  ¹   |
    | :bowtie: Other Features                                                    |      |      |      |
    | **Ranking** (sort results by relevance)                                    |  ¹   |  ¹   |  X   |
    | **Snippets** (display a few words around a match)                          |  X   |  X   |  X   |
    
    ¹ Requires extra setup, possibly hard to implement.
    
    ² Requires a [custom tokenizer](FTS5Tokenizers.md).
    
    For a full feature list, read the SQLite documentation. Some missing features can be achieved with extra application code.
    
- **The speed versus disk space constraints.** Roughly speaking, FTS4 and FTS5 are faster than FTS3, but use more space. FTS4 only supports content compression.

- **The location of the indexed text in your database schema.** Only FTS4 and FTS5 support "contentless" and "external content" tables.

- **The SQLite library integrated in your application.** The version of SQLite that ships with iOS, macOS, tvOS and watchOS supports FTS3 and FTS4 out of the box, but not always FTS5. To use FTS5, see [Enabling FTS5 Support](#enabling-fts5-support).

- See [FST3 vs. FTS4](https://www.sqlite.org/fts3.html#differences_between_fts3_and_fts4) and [FTS5 vs. FTS3/4](https://www.sqlite.org/fts5.html#appendix_a) for more differences.

> :point_up: **Note**: In case you were still wondering, it is recommended to read the SQLite documentation: [FTS3 & FTS4](https://www.sqlite.org/fts3.html) and [FTS5](https://www.sqlite.org/fts5.html).


## Create FTS3 and FTS4 Virtual Tables

**FTS3 and FTS4 full-text tables store and index textual content.**

Create tables with the `create(virtualTable:using:)` method:

```swift
// CREATE VIRTUAL TABLE document USING fts3(content)
try db.create(virtualTable: "document", using: FTS3()) { t in
    t.column("content")
}

// CREATE VIRTUAL TABLE document USING fts4(content)
try db.create(virtualTable: "document", using: FTS4()) { t in
    t.column("content")
}
```

**All columns in a full-text table contain text.** If you need to index a table that contains other kinds of values, you need an ["external content" full-text table](#external-content-full-text-tables).

You can specify a [tokenizer](#fts3-and-fts4-tokenizers):

```swift
// CREATE VIRTUAL TABLE book USING fts4(
//   tokenize=porter,
//   author,
//   title,
//   body
// )
try db.create(virtualTable: "book", using: FTS4()) { t in
    t.tokenizer = .porter
    t.column("author")
    t.column("title")
    t.column("body")
}
```

FTS4 supports [options](https://www.sqlite.org/fts3.html#fts4_options):

```swift
// CREATE VIRTUAL TABLE book USING fts4(
//   content,
//   uuid,
//   content="",
//   compress=zip,
//   uncompress=unzip,
//   prefix="2,4",
//   notindexed=uuid,
//   languageid=lid
// )
try db.create(virtualTable: "document", using: FTS4()) { t in
    t.content = ""
    t.compress = "zip"
    t.uncompress = "unzip"
    t.prefixes = [2, 4]
    t.column("content")
    t.column("uuid").notIndexed()
    t.column("lid").asLanguageId()
}
```

The `content` option is involved in "contentless" and "external content" full-text tables. GRDB can help you defining full-text tables that automatically synchronize with their content table. See [External Content Full-Text Tables](#external-content-full-text-tables).


See [SQLite documentation](https://www.sqlite.org/fts3.html) for more information.


## FTS3 and FTS4 Tokenizers

**A tokenizer defines what "matching" means.** Depending on the tokenizer you choose, full-text searches won't return the same results.

SQLite ships with three built-in FTS3/4 tokenizers: `simple`, `porter` and `unicode61` that use different algorithms to match queries with indexed content:

```swift
try db.create(virtualTable: "book", using: FTS4()) { t in
    // Pick one:
    t.tokenizer = .simple // default
    t.tokenizer = .porter
    t.tokenizer = .unicode61(...)
}
```

See below some examples of matches:

| content     | query      | simple | porter | unicode61 |
| ----------- | ---------- | :----: | :----: | :-------: |
| Foo         | Foo        |   X    |   X    |     X     |
| Foo         | FOO        |   X    |   X    |     X     |
| Jérôme      | Jérôme     |   X ¹  |   X ¹  |     X ¹   |
| Jérôme      | JÉRÔME     |        |        |     X ¹   |
| Jérôme      | Jerome     |        |        |     X ¹   |
| Database    | Databases  |        |   X    |           |
| Frustration | Frustrated |        |   X    |           |

¹ Don't miss [Unicode Full-Text Gotchas](#unicode-full-text-gotchas)

- **simple**
    
    ```swift
    try db.create(virtualTable: "book", using: FTS4()) { t in
        t.tokenizer = .simple   // default
    }
    ```
    
    The default "simple" tokenizer is case-insensitive for ASCII characters. It matches "foo" with "FOO", but not "Jérôme" with "JÉRÔME".
    
    It does not provide stemming, and won't match "databases" with "database".
    
    It does not strip diacritics from latin script characters, and won't match "jérôme" with "jerome".
    
- **porter**
    
    ```swift
    try db.create(virtualTable: "book", using: FTS4()) { t in
        t.tokenizer = .porter
    }
    ```
    
    The "porter" tokenizer compares English words according to their roots: it matches "database" with "databases", and "frustration" with "frustrated".
    
    It does not strip diacritics from latin script characters, and won't match "jérôme" with "jerome".

- **unicode61**
    
    ```swift
    try db.create(virtualTable: "book", using: FTS4()) { t in
        t.tokenizer = .unicode61()
        t.tokenizer = .unicode61(diacritics: .keep)
    }
    ```
    
    The "unicode61" tokenizer is case-insensitive for unicode characters. It matches "Jérôme" with "JÉRÔME".
    
    It strips diacritics from latin script characters by default, and matches "jérôme" with "jerome". This behavior can be disabled, as in the example above.
    
    It does not provide stemming, and won't match "databases" with "database".

See [SQLite tokenizers](https://www.sqlite.org/fts3.html#tokenizer) for more information.


## FTS3 and FTS4 Tokenization

You can tokenize strings when needed:

```swift
// Default tokenization using the `simple` tokenizer:
FTS3.tokenize("SQLite database")  // ["sqlite", "database"]
FTS3.tokenize("Gustave Doré")     // ["gustave", "doré"])

// Tokenization with an explicit tokenizer:
FTS3.tokenize("SQLite database", withTokenizer: .porter)   // ["sqlite", "databas"]
FTS3.tokenize("Gustave Doré", withTokenizer: .unicode61()) // ["gustave", "dore"])
```


## FTS3Pattern

**Full-text search in FTS3 and FTS4 tables is performed with search patterns:**

- `database` matches all documents that contain "database"
- `data*` matches all documents that contain a word starting with "data"
- `SQLite database` matches all documents that contain both "SQLite" and "database"
- `SQLite OR database` matches all documents that contain "SQLite" or "database"
- `"SQLite database"` matches all documents that contain the "SQLite database" phrase

**Not all search patterns are valid**: they must follow the [Full-Text Index Queries Grammar](https://www.sqlite.org/fts3.html#full_text_index_queries).

The FTS3Pattern type helps you validating patterns, and building valid patterns from untrusted strings (such as strings typed by users):

```swift
struct FTS3Pattern {
    init(rawPattern: String) throws
    init?(matchingAnyTokenIn string: String)
    init?(matchingAllTokensIn string: String)
    init?(matchingAllPrefixesIn string: String)
    init?(matchingPhrase string: String)
}
```

The first initializer validates your raw patterns against the query grammar, and may throw a [DatabaseError](../README.md#databaseerror):

```swift
// OK: FTS3Pattern
let pattern = try FTS3Pattern(rawPattern: "sqlite AND database")

// DatabaseError: malformed MATCH expression: [AND]
let pattern = try FTS3Pattern(rawPattern: "AND")
```

The other initializers don't throw. They build a valid pattern from any string, **including strings provided by users of your application**. They let you find documents that match any given word, all given words or prefixes, or a full phrase, depending on the needs of your application:

```swift
let query = "SQLite database"

// Matches documents that contain "SQLite" or "database"
let pattern = FTS3Pattern(matchingAnyTokenIn: query)

// Matches documents that contain "SQLite" and "database"
let pattern = FTS3Pattern(matchingAllTokensIn: query)

// Matches documents that contain words that start with "SQLite" and words that start with "database"
let pattern = FTS3Pattern(matchingAllPrefixesIn: query)

// Matches documents that contain "SQLite database"
let pattern = FTS3Pattern(matchingPhrase: query)
```

They return nil when no pattern could be built from the input string:

```swift
let pattern = FTS3Pattern(matchingAnyTokenIn: "")  // nil
let pattern = FTS3Pattern(matchingAnyTokenIn: "*") // nil
```

FTS3Pattern are regular [values](../README.md#values). You can use them as query [arguments](http://groue.github.io/GRDB.swift/docs/5.25/Structs/StatementArguments.html):

```swift
let documents = try Document.fetchAll(db,
    sql: "SELECT * FROM document WHERE content MATCH ?",
    arguments: [pattern])
```

Use them in the [query interface](../README.md#the-query-interface):

```swift
// Search in all columns
let documents = try Document.matching(pattern).fetchAll(db)

// Search in a specific column:
let documents = try Document.filter(Column("content").match(pattern)).fetchAll(db)
```


## Enabling FTS5 Support

When the FTS3 and FTS4 full-text engines don't suit your needs, you may want to use FTS5. See [Choosing the Full-Text Engine](#choosing-the-full-text-engine) to help you make a decision.

The version of SQLite that ships with iOS, macOS, tvOS and watchOS does not always support the FTS5 engine. To enable FTS5 support, you'll need to install GRDB with one of those installation techniques:

1. Use the GRDB.swift CocoaPod with a custom compilation option, as below. It uses the system SQLite, which is compiled with FTS5 support, but only on iOS 11.4+ / macOS 10.13+ / tvOS 11.4+ / watchOS 4.3+:

    ```ruby
    pod 'GRDB.swift'
    platform :ios, '11.4' # or above
    
    post_install do |installer|
      installer.pods_project.targets.select { |target| target.name == "GRDB.swift" }.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['OTHER_SWIFT_FLAGS'] = "$(inherited) -D SQLITE_ENABLE_FTS5"
        end
      end
    end
    ```
    
    > :warning: **Warning**: make sure you use the right platform version! You will get runtime errors on devices with a lower version.
    
    > :point_up: **Note**: there used to be a GRDBPlus CocoaPod with pre-enabled FTS5 support. This CocoaPod is deprecated: please switch to the above technique.

2. Use the GRDB.swift/SQLCipher CocoaPod subspec (see [encryption](../README.md#encryption)):
    
    ```ruby
    pod 'GRDB.swift/SQLCipher'
    ```
    
3. Use a [custom SQLite build] and activate the `SQLITE_ENABLE_FTS5` compilation option.


## Create FTS5 Virtual Tables

**FTS5 full-text tables store and index textual content.**

To use FTS5, you'll need a [custom SQLite build] that activates the `SQLITE_ENABLE_FTS5` compilation option.

Create FTS5 tables with the `create(virtualTable:using:)` method:

```swift
// CREATE VIRTUAL TABLE document USING fts5(content)
try db.create(virtualTable: "document", using: FTS5()) { t in
    t.column("content")
}
```

**All columns in a full-text table contain text.** If you need to index a table that contains other kinds of values, you need an ["external content" full-text table](#external-content-full-text-tables).

You can specify a [tokenizer](#fts5-tokenizers):

```swift
// CREATE VIRTUAL TABLE book USING fts5(
//   tokenize='porter',
//   author,
//   title,
//   body
// )
try db.create(virtualTable: "book", using: FTS5()) { t in
    t.tokenizer = .porter()
    t.column("author")
    t.column("title")
    t.column("body")
}
```

FTS5 supports [options](https://www.sqlite.org/fts5.html#fts5_table_creation_and_initialization):

```swift
// CREATE VIRTUAL TABLE book USING fts5(
//   content,
//   uuid UNINDEXED,
//   content='table',
//   content_rowid='id',
//   prefix='2 4',
//   columnsize=0,
//   detail=column
// )
try db.create(virtualTable: "document", using: FTS5()) { t in
    t.column("content")
    t.column("uuid").notIndexed()
    t.content = "table"
    t.contentRowID = "id"
    t.prefixes = [2, 4]
    t.columnSize = 0
    t.detail = "column"
}
```

The `content` and `contentRowID` options are involved in "contentless" and "external content" full-text tables. GRDB can help you defining full-text tables that automatically synchronize with their content table. See [External Content Full-Text Tables](#external-content-full-text-tables).

See [SQLite documentation](https://www.sqlite.org/fts5.html) for more information.


## FTS5 Tokenizers

**A tokenizer defines what "matching" means.** Depending on the tokenizer you choose, full-text searches won't return the same results.

SQLite ships with three built-in FTS5 tokenizers: `ascii`, `porter` and `unicode61` that use different algorithms to match queries with indexed content.

```swift
try db.create(virtualTable: "book", using: FTS5()) { t in
    // Pick one:
    t.tokenizer = .unicode61() // default
    t.tokenizer = .unicode61(...)
    t.tokenizer = .ascii
    t.tokenizer = .porter(...)
}
```

See below some examples of matches:

| content     | query      | ascii  | unicode61 | porter on ascii | porter on unicode61 |
| ----------- | ---------- | :----: | :-------: | :-------------: | :-----------------: |
| Foo         | Foo        |   X    |     X     |        X        |          X          |
| Foo         | FOO        |   X    |     X     |        X        |          X          |
| Jérôme      | Jérôme     |   X ¹  |     X ¹   |        X ¹      |          X ¹        |
| Jérôme      | JÉRÔME     |        |     X ¹   |                 |          X ¹        |
| Jérôme      | Jerome     |        |     X ¹   |                 |          X ¹        |
| Database    | Databases  |        |           |        X        |          X          |
| Frustration | Frustrated |        |           |        X        |          X          |

¹ Don't miss [Unicode Full-Text Gotchas](#unicode-full-text-gotchas)

- **unicode61**
    
    ```swift
    try db.create(virtualTable: "book", using: FTS5()) { t in
        t.tokenizer = .unicode61()
        t.tokenizer = .unicode61(diacritics: .keep)
    }
    ```
    
    The default "unicode61" tokenizer is case-insensitive for unicode characters. It matches "Jérôme" with "JÉRÔME".
    
    It strips diacritics from latin script characters by default, and matches "jérôme" with "jerome". This behavior can be disabled, as in the example above.
    
    It does not provide stemming, and won't match "databases" with "database".

- **ascii**
    
    ```swift
    try db.create(virtualTable: "book", using: FTS5()) { t in
        t.tokenizer = .ascii()
    }
    ```
    
    The "ascii" tokenizer is case-insensitive for ASCII characters. It matches "foo" with "FOO", but not "Jérôme" with "JÉRÔME".
    
    It does not provide stemming, and won't match "databases" with "database".
    
    It does not strip diacritics from latin script characters, and won't match "jérôme" with "jerome".
    
- **porter**
    
    ```swift
    try db.create(virtualTable: "book", using: FTS5()) { t in
        t.tokenizer = .porter()         // porter wrapping unicode61 (the default)
        t.tokenizer = .porter(.ascii()) // porter wrapping ascii
        t.tokenizer = .porter(.unicode61(diacritics: .keep)) // porter wrapping unicode61 without diacritics stripping
    }
    ```
    
    The porter tokenizer is a wrapper tokenizer which compares English words according to their roots: it matches "database" with "databases", and "frustration" with "frustrated".
    
    It strips diacritics from latin script characters if it wraps unicode61, and does not if it wraps ascii (see the example above).

See [SQLite tokenizers](https://www.sqlite.org/fts5.html#tokenizers) for more information, and [custom FTS5 tokenizers](FTS5Tokenizers.md) in order to add your own tokenizers.


## FTS5 Tokenization

You can tokenize strings when needed:

```swift
let ascii = try db.makeTokenizer(.ascii())

// Tokenize an FTS5 query
for (token, flags) in try ascii.tokenize(query: "SQLite database") {
    print(token) // Prints "sqlite" then "database"
}

// Tokenize an FTS5 document
for (token, flags) in try ascii.tokenize(document: "SQLite database") {
    print(token) // Prints "sqlite" then "database"
}
```

Some tokenizers may produce a different output when you tokenize a query or a document (see `FTS5_TOKENIZE_QUERY` and `FTS5_TOKENIZE_DOCUMENT` in https://www.sqlite.org/fts5.html#custom_tokenizers). You should generally use `tokenize(query:)` when you intend to tokenize a string in order to compose a [raw search pattern](#fts5pattern).

See the `FTS5_TOKEN_*` flags in https://www.sqlite.org/fts5.html#custom_tokenizers for more information about token flags. In particular, tokenizers that support synonyms may output multiple tokens for a single word, along with the `.colocated` flag.


## FTS5Pattern

**Full-text search in FTS5 tables is performed with search patterns:**

- `database` matches all documents that contain "database"
- `data*` matches all documents that contain a word starting with "data"
- `SQLite database` matches all documents that contain both "SQLite" and "database"
- `SQLite OR database` matches all documents that contain "SQLite" or "database"
- `"SQLite database"` matches all documents that contain the "SQLite database" phrase

**Not all search patterns are valid**: they must follow the [Full-Text Query Syntax](https://www.sqlite.org/fts5.html#full_text_query_syntax).

The FTS5Pattern type helps you validating patterns, and building valid patterns from untrusted strings (such as strings typed by users):

```swift
extension Database {
    func makeFTS5Pattern(rawPattern: String, forTable table: String) throws -> FTS5Pattern
}

struct FTS5Pattern {
    init?(matchingAnyTokenIn string: String)
    init?(matchingAllTokensIn string: String)
    init?(matchingAllPrefixesIn string: String)
    init?(matchingPhrase string: String)
    init?(matchingPrefixPhrase string: String)
}
```

The `Database.makeFTS5Pattern(rawPattern:forTable:)` method validates your raw patterns against the query grammar and the columns of the targeted table, and may throw a [DatabaseError](../README.md#databaseerror):

```swift
// OK: FTS5Pattern
try db.makeFTS5Pattern(rawPattern: "sqlite", forTable: "book")

// DatabaseError: syntax error near \"AND\"
try db.makeFTS5Pattern(rawPattern: "AND", forTable: "book")

// DatabaseError: no such column: missing
try db.makeFTS5Pattern(rawPattern: "missing: sqlite", forTable: "book")
```

The FTS5Pattern initializers don't throw. They build a valid pattern from any string, **including strings provided by users of your application**. They let you find documents that match all given words, any given word, or a full phrase, depending on the needs of your application:

```swift
let query = "SQLite database"

// Matches documents that contain "SQLite" or "database"
let pattern = FTS5Pattern(matchingAnyTokenIn: query)

// Matches documents that contain "SQLite" and "database"
let pattern = FTS5Pattern(matchingAllTokensIn: query)

// Matches documents that contain words that start with "SQLite" and words that start with "database"
let pattern = FTS5Pattern(matchingAllPrefixesIn: query)

// Matches documents that contain "SQLite database"
let pattern = FTS5Pattern(matchingPhrase: query)

// Matches documents that start with "SQLite database"
let pattern = FTS5Pattern(matchingPrefixPhrase: query)
```

They return nil when no pattern could be built from the input string:

```swift
let pattern = FTS5Pattern(matchingAnyTokenIn: "")  // nil
let pattern = FTS5Pattern(matchingAnyTokenIn: "*") // nil
```

FTS5Pattern are regular [values](../README.md#values). You can use them as query [arguments](http://groue.github.io/GRDB.swift/docs/5.25/Structs/StatementArguments.html):

```swift
let documents = try Document.fetchAll(db,
    sql: "SELECT * FROM document WHERE document MATCH ?",
    arguments: [pattern])
```

Use them in the [query interface](../README.md#the-query-interface):

```swift
// Search in all columns
let documents = try Document.matching(pattern).fetchAll(db)

// Search in a specific column:
let documents = try Document.filter(Column("content").match(pattern)).fetchAll(db)
```


## FTS5: Sorting by Relevance

**FTS5 can sort results by relevance** (most to least relevant):

```swift
// SQL
let documents = try Document.fetchAll(db,
    sql: "SELECT * FROM document WHERE document MATCH ? ORDER BY rank",
    arguments: [pattern])

// Query Interface
let documents = try Document.matching(pattern).order(Column.rank).fetchAll(db)
```

For more information about the ranking algorithm, as well as extra options, read [Sorting by Auxiliary Function Results](https://www.sqlite.org/fts5.html#sorting_by_auxiliary_function_results)

GRDB does not provide any ranking for FTS3 and FTS4. See SQLite's [Search Application Tips](https://www.sqlite.org/fts3.html#appendix_a) if you really need it.


## External Content Full-Text Tables

**An external content table does not store the indexed text.** Instead, it indexes the text stored in another table.

This is very handy when you want to index a table that can not be declared as a full-text table (because it contains non-textual values, for example). You just have to define an external content full-text table that refers to the regular table.

The two tables must be kept up-to-date, so that the full-text index matches the content of the regular table. This synchronization happens automatically if you use the `synchronize(withTable:)` method in your full-text table definition:

```swift
// A regular table
try db.create(table: "book") { t in
    t.column("author", .text)
    t.column("title", .text)
    t.column("content", .text)
    ...
}

// A full-text table synchronized with the regular table
try db.create(virtualTable: "book_ft", using: FTS4()) { t in // or FTS5()
    t.synchronize(withTable: "book")
    t.column("author")
    t.column("title")
    t.column("content")
}
```

The eventual content already present in the regular table is indexed, and every insert, update or delete that happens in the regular table is automatically applied to the full-text index.

For more information, see the SQLite documentation about external content tables: [FTS4](https://www.sqlite.org/fts3.html#_external_content_fts4_tables_), [FTS5](https://sqlite.org/fts5.html#external_content_tables).

See also [WWDC Companion](https://github.com/groue/WWDCCompanion), a sample app that uses external content tables to store, display, and let the user search the WWDC sessions.


### Deleting Synchronized Full-Text Tables

Synchronization of full-text tables with their content table happens by the mean of SQL triggers.

SQLite automatically deletes those triggers when the content (not full-text) table is dropped.

However, those triggers remain after the full-text table has been dropped. Unless they are dropped too, they will prevent future insertion, updates, and deletions in the content table, and the creation of a new full-text table.

To drop those triggers, use the `dropFTS4SynchronizationTriggers` or `dropFTS5SynchronizationTriggers` methods:

```swift
// Create tables
try db.create(table: "book") { t in
    ...
}
try db.create(virtualTable: "book_ft", using: FTS4()) { t in
    t.synchronize(withTable: "book")
    ...
}

// Drop full-text table
try db.drop(table: "book_ft")
try db.dropFTS4SynchronizationTriggers(forTable: "book_ft")
```

> :warning: **Warning**: there was a bug in GRDB up to version 2.3.1 included, which created triggers with a wrong name. If it is possible that the full-text table was created by an old version of GRDB, then delete the synchronization triggers **twice**: once with the name of the deleted full-text table, and once with the name of the content table:
>
> ```swift
> // Drop full-text table
> try db.drop(table: "book_ft")
> try db.dropFTS4SynchronizationTriggers(forTable: "book_ft")
> try db.dropFTS4SynchronizationTriggers(forTable: "book") // Support for GRDB <= 2.3.1
> ```



### Querying External Content Full-Text Tables

When you need to perform a full-text search, and the external content table contains all the data you need, you can simply query the full-text table.

But if you need to load columns from the regular table, and in the same time perform a full-text search, then you will need to query both tables at the same time.

That is because SQLite will throw an error when you try to perform a full-text search on a regular table:

```swift
// SQLite error 1: unable to use function MATCH in the requested context
// SELECT * FROM book WHERE book MATCH '...'
let books = Book.matching(pattern).fetchAll(db)
```

The solution is to perform a joined request, using raw SQL:

```swift
let sql = """
    SELECT book.*
    FROM book
    JOIN book_ft
        ON book_ft.rowid = book.rowid
        AND book_ft MATCH ?
    """
let books = Book.fetchAll(db, sql: sql, arguments: [pattern])
```


## Full-Text Records

**You can define [record](../README.md#records) types around the full-text virtual tables.**

However these tables don't have any explicit primary key. Instead, they use the [implicit rowid primary key](../README.md#the-implicit-rowid-primary-key): a special hidden column named `rowid`.

You will have to [expose this hidden column](../README.md#exposing-the-rowid-column) in order to fetch, delete, and update full-text records by primary key.


## Unicode Full-Text Gotchas

The SQLite built-in tokenizers for [FTS3, FTS4](#fts3-and-fts4-tokenizers) and [FTS5](#fts5-tokenizers) are generally unicode-aware, with a few caveats, and limitations.

Generally speaking, matches may fail when content and query don't use the same [unicode normalization](http://unicode.org/reports/tr15/). SQLite actually exhibits inconsistent behavior in this regard.

For example, for "aimé" to match "aimé", they better have the same normalization: the NFC "aim\u{00E9}" form may not match its NFD "aime\u{0301}" equivalent. Most strings that you get from Swift, UIKit and Cocoa use NFC, so be careful with NFD inputs (such as strings from the HFS+ file system, or strings that you can't trust like network inputs). Use [String.precomposedStringWithCanonicalMapping](https://developer.apple.com/documentation/foundation/nsstring/1412645-precomposedstringwithcanonicalma) to turn a string into NFC.

Besides, if you want "fi" to match the ligature "&#xfb01;" (U+FB01), then you need to normalize your indexed contents and inputs to NFKC or NFKD. Use [String.precomposedStringWithCompatibilityMapping](https://developer.apple.com/documentation/foundation/nsstring/1412625-precomposedstringwithcompatibili) to turn a string into NFKC.

Unicode normalization is not the end of the story, because it won't help "Encyclopaedia" match "Encyclopædia", "Mueller", "Müller", "Grossmann", "Großmann", or "Diyarbakır", "DIYARBAKIR". The [String.applyingTransform](https://developer.apple.com/documentation/foundation/nsstring/1407787-applyingtransform) method can help.

GRDB lets you write [custom FTS5 tokenizers](FTS5Tokenizers.md) that can transparently deal with all these issues. For FTS3 and FTS4, you'll need to pre-process your strings before injecting them in the full-text engine.

Happy indexing!


