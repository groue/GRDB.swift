# Database Schema Introspection

Get information about schema objects such as tables, columns, indexes, foreign keys, etc.

## Topics

### Querying the Database Schema

- ``Database/columns(in:in:)``
- ``Database/foreignKeys(on:in:)``
- ``Database/indexes(on:in:)``
- ``Database/isGRDBInternalTable(_:)``
- ``Database/isSQLiteInternalTable(_:)``
- ``Database/primaryKey(_:in:)``
- ``Database/schemaVersion()``
- ``Database/table(_:hasUniqueKey:)``
- ``Database/tableExists(_:in:)``
- ``Database/triggerExists(_:in:)``
- ``Database/viewExists(_:in:)``
- ``ColumnInfo``
- ``ForeignKeyInfo``
- ``IndexInfo``
- ``PrimaryKeyInfo``
