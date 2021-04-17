Distinctive Features of GRDB
============================

This page highlights some of the characteristics of GRDB that are unusual, and make it different from many other database toolkits.

### Schema Freedom

GRDB accepts all database schemas. There is no constraint on the structure of tables, views, primary, secondary and foreign keys, SQL triggers, etc. Your modelling and SQLite skills are welcomed: GRDB fosters robust database schemas that fit your application needs, able to outlive your Swift code.

Many other toolkits put restrictions on your database schemas, such as enforcing a key-value store, or requiring a single-column primary key when you do not want it.

### Database Observation

GRDB can [observe database changes](../README.md#database-changes-observation). This makes it easy, for example, to keep your application views up-to-date. All the Combine or RxSwift tooling you expect is ready-made.

Observation is entirely implemented on top of SQLite-level features, and this allows GRDB to notify changes performed through its high-level Swift APIs, through raw SQL, and even indirect changes that happen through foreign keys actions or SQL triggers.

Many other toolkits can not observe the database, or will not notice changes performed with low-level database accesses.

### No base Record type, no property wrappers, no keypath-based queries

GRDB can turn any Swift type into a [record type](../README.md#records) that can be stored in a database table, or fetched at will from a suitable database query. Such record types are much easier to deal with than raw database rows.

Because record types do not have to derive from a base class, you can leverage `struct` immutability if you want it.

Because GRDB does not need keypaths or property wrappers to generate SQL queries, you can freely design your record properties, and perform as much [information hiding](https://en.wikipedia.org/wiki/Information_hiding) as needed.

Some other toolkits make a liberal use of base classes, mandatory property wrappers, or keypaths. This creates an unnecessary dependency on database-level implementation details, which is better avoided when possible (and it is possible).

### Convenience and Performance: pick both

GRDB leverages the standard [Codable](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types) protocol because it is quite handy. However when one looks after sheer performance, GRDB makes it possible to avoid all the slow runtime machinery of Codable, and run as close to the SQL metal as possible.

Other toolkits don't run [quite as fast](https://github.com/groue/GRDB.swift/wiki/Performance).

### WAL Mode

The [WAL mode](https://sqlite.org/wal.html) allows SQLite to support concurrent accesses, and improves the performance of multi-threaded applications.

GRDB not only supports the WAL mode (with [DatabasePool](../README.md#database-pools)), but you can write code that accept both WAL and non-WAL databases. Your tests or your SwiftUI previews can run in a fast non-WAL in-memory database, while your main application uses an efficient WAL database on disk.

Many other toolkits do not support the WAL mode, or leave it as an exercise for the application developer.

### To the point documentation

No GRDB feature ships until it is possible to write its documentation in a way that makes sense. GRDB guides are targetted at solving application problems. They gradually exposes features with their benefits, and caveats, in order to avoid misuses or bad surprises.

### A pro toolkit that welcomes beginners

GRDB helps you focus on the two facets of your database work that that no one else can do for you: defining the database schema, and transaction boundaries. Those two fundamental tasks are always up to you.

All other SQLite subtleties are handled by default in the most safe manner by GRDB, and power users have all the escape hatches they need. Consider that all GRDB features used to live at application level before they were polished enough to enter the library. This means that features that are not available through ready-made GRDB APIs are generally available one level below, and that you're unlikely to face any wall.

Many other toolkits leave too much hard work for the developers, or build impassable fences.
