# ``GRDB``

A toolkit for SQLite databases, with a focus on application development

## Overview

GRDB provides raw access to SQL and advanced SQLite features, because one sometimes enjoys a sharp tool. It has robust concurrency primitives, so that multi-threaded applications can efficiently use their databases. It grants your application models with persistence and fetching methods, so that you don't have to deal with SQL and raw database rows when you don't want to.


## Topics

### Database Connections

- ``Configuration``
- ``DatabasePool``
- ``DatabaseQueue``
- ``DatabaseSnapshot``
- ``Database``
- ``DatabaseReader``
- ``DatabaseWriter``

### Errors

- ``DatabaseError``
- ``PersistenceError``

### Migrations

- ``DatabaseMigrator``

### Database Rows & Values

- ``DatabaseValue``
- ``Row``
- ``DatabaseValueConvertible``
- ``StatementColumnConvertible``

### Records

- ``Record``
- ``EncodableRecord``
- ``FetchableRecord``
- ``MutablePersistableRecord``
- ``PersistableRecord``
- ``TableRecord``

### Requests

- ``AdaptedFetchRequest``
- ``QueryInterfaceRequest``
- ``SQLRequest``
- ``FetchRequest``

### The Query Interface

- ``AllColumns``
- ``Column``
- ``CommonTableExpression``
- ``ForeignKey``
- ``QueryInterfaceRequest``
- ``SQLExpression``
- ``SQLOrdering``
- ``SQLSelection``
- ``SQLSubquery``
- ``Table``
- ``Association``
- ``ColumnExpression``
- ``DerivableRequest``
- ``SQLExpressible``
- ``SQLOrderingTerm``
- ``SQLSelectable``
- ``SQLSpecificExpressible``
- ``SQLSubqueryable``

### Database Observation

- ``AsyncValueObservation``
- ``DatabaseRegion``
- ``DatabaseRegionConvertible``
- ``DatabaseRegionObservation``
- ``SharedValueObservation``
- ``ValueObservation``
- ``ValueObservationScheduler``
- ``TransactionObserver``

### Full-Text Search

- ``FTS3``
- ``FTS4``
