# Transactions and Savepoints

Precise transaction handling.

## Transactions and Safety

**A transaction is a fundamental tool of SQLite** that guarantees [data consistency](https://www.sqlite.org/transactional.html) as well as [proper isolation](https://sqlite.org/isolation.html) between application threads and database connections. It is at the core of GRDB <doc:Concurrency> guarantees.

To profit from database transactions, all you have to do is group related database statements in a single database access method such as ``DatabaseWriter/write(_:)-76inz`` or ``DatabaseReader/read(_:)-3806d``:

```swift
// BEGIN TRANSACTION
// INSERT INTO credit ...
// INSERT INTO debit ...
// COMMIT
try dbQueue.write { db in
    try Credit(destinationAccount, amount).insert(db)
    try Debit(sourceAccount, amount).insert(db)
}

// BEGIN TRANSACTION
// SELECT * FROM credit
// SELECT * FROM debit
// COMMIT
let (credits, debits) = try dbQueue.read { db in
    let credits = try Credit.fetchAll(db)
    let debits = try Debit.fetchAll(db)
    return (credits, debits)
}
```

In the following sections we'll explore how you can avoid transactions, and how to perform explicit transactions and savepoints. 

## Database Accesses without Transactions

When needed, you can write outside of any transaction with ``DatabaseWriter/writeWithoutTransaction(_:)-4qh1w`` (also named `inDatabase(_:)`, for `DatabaseQueue`):

```swift
// INSERT INTO credit ...
// INSERT INTO debit ...
try dbQueue.writeWithoutTransaction { db in
    try Credit(destinationAccount, amount).insert(db)
    try Debit(sourceAccount, amount).insert(db)
}
```

For reads, use ``DatabaseReader/unsafeRead(_:)-5i7tf``:

```swift
// SELECT * FROM credit
// SELECT * FROM debit
let (credits, debits) = try dbPool.unsafeRead { db in
    let credits = try Credit.fetchAll(db)
    let debits = try Debit.fetchAll(db)
    return (credits, debits)
}
```

Those method names, `writeWithoutTransaction` and `unsafeRead`, are longer and "scarier" than the regular `write` and `read` in order to draw your attention to the dangers of those unisolated accesses.

In our credit/debit example, a credit may be successfully inserted, but the debit insertion may fail, ending up with unbalanced accounts (oops).

```swift
// UNSAFE DATABASE INTEGRITY
try dbQueue.writeWithoutTransaction { db in // or dbPool.writeWithoutTransaction
    try Credit(destinationAccount, amount).insert(db)
    // 😬 May fail after credit was successfully written to disk:
    try Debit(sourceAccount, amount).insert(db)       
}
```

Transactions avoid this kind of bug.
    
``DatabasePool`` concurrent reads can see an inconsistent state of the database:

```swift
// UNSAFE CONCURRENCY
try dbPool.writeWithoutTransaction { db in
    try Credit(destinationAccount, amount).insert(db)
    // <- 😬 Here a concurrent read sees a partial db update (unbalanced accounts)
    try Debit(sourceAccount, amount).insert(db)
}
```

Transactions avoid this kind of bug, too.

Finally, reads performed outside of any transaction are not isolated from concurrent writes. It is possible to see unbalanced accounts, even though the invariant is never broken on disk:

```swift
// UNSAFE CONCURRENCY
let (credits, debits) = try dbPool.unsafeRead { db in
    let credits = try Credit.fetchAll(db)
    // <- 😬 Here a concurrent write can modify the balance before debits are fetched
    let debits = try Debit.fetchAll(db)
    return (credits, debits)
}
```

Yes, transactions also avoid this kind of bug.

## Explicit Transactions

To open explicit transactions, use `inTransaction()` or `writeInTransaction()`:

```swift
// BEGIN TRANSACTION
// INSERT INTO credit ...
// INSERT INTO debit ...
// COMMIT
try dbQueue.inTransaction { db in // or dbPool.writeInTransaction
    try Credit(destinationAccount, amount).insert(db)
    try Debit(sourceAccount, amount).insert(db)
    return .commit
}

// BEGIN TRANSACTION
// INSERT INTO credit ...
// INSERT INTO debit ...
// COMMIT
try dbQueue.writeWithoutTransaction { db in
    try db.inTransaction {
        try Credit(destinationAccount, amount).insert(db)
        try Debit(sourceAccount, amount).insert(db)
        return .commit
    }
}
```

If an error is thrown from the transaction block, the transaction is rollbacked and the error is rethrown by the transaction method. If the transaction closure returns `.rollback` instead of `.commit`, the transaction is also rollbacked, but no error is thrown.

Full manual transaction management is also possible: 

```swift
try dbQueue.writeWithoutTransaction { db
    try db.beginTransaction()
    ...
    try db.commit()
    
    try db.execute(sql: "BEGIN TRANSACTION")
    ...
    try db.execute(sql: "ROLLBACK")
}
```

Transactions can't be left opened unless the ``Configuration/allowsUnsafeTransactions`` configuration flag is set:

```swift
// fatal error: A transaction has been left opened at the end of a database access
try dbQueue.writeWithoutTransaction { db in
    try db.execute(sql: "BEGIN TRANSACTION")
    // <- no commit or rollback
}
```

It is possible to ask if a transaction is currently opened:

```swift
func myCriticalMethod(_ db: Database) throws {
    precondition(db.isInsideTransaction, "This method requires a transaction")
    try ...
}
```

Yet, there is a better option than checking for transactions. Critical database sections should use savepoints, described below:

```swift
func myCriticalMethod(_ db: Database) throws {
    try db.inSavepoint {
        // Here the database is guaranteed to be inside a transaction.
        try ...
    }
}
```

## Savepoints

**Statements grouped in a savepoint can be rollbacked without invalidating a whole transaction:**

```swift
try dbQueue.write { db in
    // Makes sure both inserts succeed, or none:
    try db.inSavepoint {
        try Credit(destinationAccount, amount).insert(db)
        try Debit(sourceAccount, amount).insert(db)
        return .commit
    }
    
    // Other savepoints, etc...
}
```

If an error is thrown from the savepoint block, the savepoint is rollbacked and the error is rethrown by the `inSavepoint` method. If the savepoint closure returns `.rollback` instead of `.commit`, the savepoint is also rollbacked, but no error is thrown.

**Unlike transactions, savepoints can be nested.** They implicitly open a transaction if no one was opened when the savepoint begins. As such, they behave just like nested transactions. Yet the database changes are only written to disk when the outermost transaction is committed:

```swift
try dbQueue.writeWithoutTransaction { db in
    try db.inSavepoint {
        ...
        try db.inSavepoint {
            ...
            return .commit
        }
        ...
        return .commit // Writes changes to disk
    }
}
```

SQLite savepoints are more than nested transactions, though. For advanced uses, use [SQLite savepoint documentation](https://www.sqlite.org/lang_savepoint.html).


## Transaction Kinds

SQLite supports [three kinds of transactions](https://www.sqlite.org/lang_transaction.html): deferred (the default), immediate, and exclusive.

The transaction kind can be chosen for individual transaction:

```swift
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

// BEGIN EXCLUSIVE TRANSACTION ...
try dbQueue.inTransaction(.exclusive) { db in ... }
```

It is also possible to configure the ``Configuration/defaultTransactionKind``:

```swift
var config = Configuration()
config.defaultTransactionKind = .immediate

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: config)

// BEGIN IMMEDIATE TRANSACTION ...
try dbQueue.write { db in ... }

// BEGIN IMMEDIATE TRANSACTION ...
try dbQueue.inTransaction { db in ... }
```
