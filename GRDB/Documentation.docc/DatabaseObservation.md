# Database Observation

Observe database changes and transactions.

## Overview

**SQLite notifies its host application of changes performed to the database, as well of transaction commits and rollbacks.**

GRDB puts this SQLite feature to some good use, and lets you observe the database in various ways:

- ``ValueObservation``: Get notified when database values change.
- ``DatabaseRegionObservation``: Get notified when a transaction impacts a database region.
- ``Database/afterNextTransaction(onCommit:onRollback:)``: Handle transactions commits or rollbacks, one by one.
- ``TransactionObserver``: The low-level protocol that supports all database observation features.

## Topics

### Observing Database Values

- ``ValueObservation``
- ``SharedValueObservation``
- ``AsyncValueObservation``
- ``Database/registerAccess(to:)``

### Observing Database Transactions

- ``DatabaseRegionObservation``
- ``Database/afterNextTransaction(onCommit:onRollback:)``

### Low-Level Transaction Observers

- ``TransactionObserver``
- ``Database/add(transactionObserver:extent:)``
- ``Database/remove(transactionObserver:)``
- ``DatabaseWriter/add(transactionObserver:extent:)``
- ``DatabaseWriter/remove(transactionObserver:)``
- ``Database/TransactionObservationExtent``

### Database Regions

- ``DatabaseRegion``
- ``DatabaseRegionConvertible``
