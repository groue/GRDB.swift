# ``GRDB``

A toolkit for SQLite databases, with a focus on application development

## Overview

Use GRDB to save your application’s permanent data into SQLite databases.

The library provides raw access to SQL and advanced SQLite features, because one sometimes enjoys a sharp tool.

It has robust concurrency primitives, so that multi-threaded applications can efficiently use their databases.

It grants your application models with persistence and fetching methods, so that you don't have to deal with SQL and raw database rows when you don't want to.

Compared to [SQLite.swift](https://github.com/stephencelis/SQLite.swift) or [FMDB](https://github.com/ccgus/fmdb), GRDB can spare you a lot of glue code. Compared to [Core Data](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CoreData/) or [Realm](http://realm.io), it can simplify your multi-threaded applications.

## Topics

### Fundamentals

- <doc:DatabaseConnections>
- <doc:SQLSupport>
- <doc:Concurrency>
- <doc:Transactions>

### Migrations and The Database Schema

- <doc:DatabaseSchema>
- <doc:Migrations>
- <doc:SingleRowTables>

### Records and the Query Interface

- <doc:QueryInterface>

### Responding to Database Changes

- <doc:DatabaseObservation>

### Full-Text Search

- <doc:FullTextSearch>

### Combine Publishers

- ``DatabasePublishers``
