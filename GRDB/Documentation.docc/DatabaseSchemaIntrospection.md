# Database Schema Introspection

Get information about schema objects such as tables, columns, indexes, foreign keys, etc.

## Topics

### Querying the Schema Version

- ``Database/schemaVersion()``

### Existence Checks

- ``Database/tableExists(_:in:)``
- ``Database/triggerExists(_:in:)``
- ``Database/viewExists(_:in:)``

### Table Structure

- ``Database/columns(in:in:)``
- ``Database/foreignKeys(on:in:)``
- ``Database/indexes(on:in:)``
- ``Database/primaryKey(_:in:)``
- ``Database/table(_:hasUniqueKey:)``

### Reserved Tables

- ``Database/isGRDBInternalTable(_:)``
- ``Database/isSQLiteInternalTable(_:)``

### Supporting Types

- ``ColumnInfo``
- ``ForeignKeyInfo``
- ``IndexInfo``
- ``PrimaryKeyInfo``
