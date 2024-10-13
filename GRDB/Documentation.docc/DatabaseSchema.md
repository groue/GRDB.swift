# The Database Schema

Define or query the database schema.

## Overview

**GRDB supports all database schemas, and has no requirement.** Any existing SQLite database can be opened, and you are free to structure your new databases as you wish.

You perform modifications to the database schema with methods such as ``Database/create(table:options:body:)``, listed in <doc:DatabaseSchemaModifications>. For example:

```swift
try db.create(table: "player") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("name", .text).notNull()
    t.column("score", .integer).notNull()
}
```

Most applications modify the database schema as new versions ship: it is recommended to wrap all schema changes in <doc:Migrations>.

## Topics

### Define the database schema

- <doc:DatabaseSchemaModifications>
- <doc:DatabaseSchemaRecommendations>

### Introspect the database schema

- <doc:DatabaseSchemaIntrospection>

### Check the database schema

- <doc:DatabaseSchemaIntegrityChecks>
