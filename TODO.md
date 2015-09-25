- [ ] #2: this commit may be how stephencelis fixed it: https://github.com/stephencelis/SQLite.swift/commit/8f64e357c3a6668c5f011c91ba33be3e8d4b88d0
- [ ] Use @warn_unused_result
- [ ] Since Records' primary key are infered, no operation is possible on the primary key unless we have a Database instance. It's impossible to define the record.primaryKey property, or to provide a copy() function that does not clone the primary key: they miss the database that is the only object aware of the primary key. Should we change our mind, and have Record explicitly expose their primary key again?
- [ ] Metal: review all fetch() and fetchAll() methods, and make sure they still work even when they use metal row. This include:
    - [ ] Write test for how a fetched sequence should behave. It should contains the expected values. It can be restarted. Some of those are already written.
- [ ] Metal: How does the code look like when one iterates metal row and extracts NSData without copy?
- [ ] Update or delete the "Value Extraction in Details" paragraph in README.md
- [ ] Talk about SQLiteStatementConvertible. Maybe in a special "Performance" section.

Not sure:

- [ ] See if we can avoid the inelegant `dbQueue.inTransaction(.Deferred) { ...; return .Commit }` that is required for isolation of select queries, without introducing any ambiguity.


Require changes in the Swift language:

- [ ] Turn DatabaseIntRepresentable and DatabaseStringRepresentable into SQLiteStatementConvertible when Swift allows for it.
- [ ] Specific and optimized Optional<SQLiteStatementConvertible>.fetch... methods when rdar://22852669 is fixed.
