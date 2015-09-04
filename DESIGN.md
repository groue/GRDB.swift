The Design of GRDB.swift
========================

More than caveats or defects, there are a few glitches, or surprises in the GRDB.swift API. We try to explain them here.

- Why `db.fetch(Int.self, "SELECT ...")` instead of `Int.fetch(db, "SELECT ...")`?
- Why can't NSObject adopt DatabaseValueConvertible, so that native NSDate, NSData, UIImage could be used as query arguments, or fetched values?
- Why is RowModel a class, when protocols are all the rage?


**Why `db.fetch(Int.self, "SELECT ...")` instead of `Int.fetch(db, "SELECT ...")`?**

The same question is raised for row models: wouldn't `Person.fetchOne(db, primaryKey: 12)` be nicer than `db.fetchOne(Person.self, primaryKey: 12)`?

Well, this is quite possible to achieve, with protocol extensions. The original idea comes from [@capttaco](https://twitter.com/capttaco/status/623960943630880769), and the [Fetchable2](https://github.com/groue/GRDB.swift/tree/Fetchable2) branch of GRDB.swift explores this idea.

And this has not shipped in the main branch, because protocol extensions don't play well with class hierarchies. RowModel is a class designed for subclassing, and multi-level hierarchies are a [wonderful feature](README.md#ad-hoc-subclasses) of this class: the library needs minimal friction in this area.

Here is what typical user code looks like today:

```swift
// A class that maps a database table
class Person: RowModel {
    // Usually one property per column.
}

// An ad-hoc subclass that targets a specific use of the database:
class PersonWithExtraColumns: Person {
    // Support for a few extra columns such as aggregate values,
    // or columns from a dependent model.
}

// Here we go
let persons = db.fetch(PersonWithExtraColumns.self, "SELECT ...")
```

And here is what user code looks like in the discarded Fetchable2 branch:

```swift
// Extra DatabaseFetchable protocol declaration
class Person: RowModel, DatabaseFetchable {
}

// Mandatory definition of the FetchedType typealias
class PersonWithExtraColumns: Person {
    typealias FetchedType = PersonWithExtraColumns
}

// Gee! PersonWithExtraColumns.fetch!
let persons = PersonWithExtraColumns.fetch(db, "SELECT ...")
```

TO BE CONTINUED...
