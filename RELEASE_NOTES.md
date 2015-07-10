Release Notes
=============

## Future release

**New**

- `Blob.init?(NSData?)`. It returns nil for empty data, because SQLite can't store zero-length blobs.
- `RowModel.isDirty`. Updating non dirty models does not touch the database.


## v0.2.0

**Breaking changes**

- Requires Xcode 7.0 beta 3

**New**

- `RowModelError.InvalidDatabaseDictionary`: new error case that helps you designing a fine RowModel subclass.


## v0.1.0

Initial release
