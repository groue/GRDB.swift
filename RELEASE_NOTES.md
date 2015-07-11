Release Notes
=============

## v0.3.0

Released July 11, 2015

**New**

- `Blob.init?(NSData?)`.
- `RowModel.isEdited`.
- `RowModel.copyDatabaseValuesFrom(_:)`
- `DatabaseValue` adopts Equatable.

**Breaking changes**

- `RowModelError.UnspecifiedTable` and `RowModelError.InvalidDatabaseDictionary` have been replaced with fatal errors that point a programming error.

## v0.2.0

Released July 9, 2015

**Breaking changes**

- Requires Xcode 7.0 beta 3

**New**

- `RowModelError.InvalidDatabaseDictionary`: new error case that helps you designing a fine RowModel subclass.


## v0.1.0

Released July 9, 2015

Initial release
