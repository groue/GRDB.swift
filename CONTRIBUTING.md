Contributing to GRDB
====================

**Thank you for coming!**

This guide is a set of tips and guidelines for contributing to the GitHub repository [groue/GRDB.swift](https://github.com/groue/GRDB.swift).

- [Report Bugs]
- [Ask Questions]
- [Suggest an Enhancement]
- [Submit a Pull Request]
- [Sponsoring and Professional Support]
- [Suggested Contributions]
- [Non-Goals]


### Report Bugs

Please make sure the bug is not already reported by searching existing [issues](https://github.com/groue/GRDB.swift/issues).

If you're unable to find an existing issue addressing the problem, [open a new one](https://github.com/groue/GRDB.swift/issues/new). Be sure to include a title and clear description, as much relevant information as possible, and a code sample or an executable test case demonstrating the expected behavior that is not occurring.


### Ask Questions

The information you are looking for is maybe already available. Check out:

- the [FAQ](README.md#faq)
- the [general documentation](README.md#documentation)
- the [answered questions](https://github.com/groue/GRDB.swift/issues?utf8=✓&q=label%3Aquestion+)

If not, your questions are welcome in the [GRDB forums](https://forums.swift.org/c/related-projects/grdb), or in a new [GitHub issue](https://github.com/groue/GRDB.swift/issues/new). 


### Suggest an Enhancement

Your idea may already be listed in [Suggested Contributions], waiting for someone to pick it up.

If not, contact [@groue](http://twitter.com/groue) on Twitter, or [open a new issue](https://github.com/groue/GRDB.swift/issues/new).


### Submit a Pull Request

Discuss your idea first, so that your changes have a good chance of being merged in.

Submit your pull request against the `development` branch.

Pull requests that include tests for modified and new functionalities, inline documentation, and relevant updates to the main README.md are merged faster, because you won't have to wait for somebody else to complete your contribution.


### Sponsoring and Professional Support

GRDB is free. It is openly developed by its contributors, on their free time, according to their will, needs, and availability. It is not controlled by any company.

When you have specific development or support needs, and are willing to financially contribute to GRDB, please send an email to [Gwendal Roué](mailto:gr@pierlis.com) so that we can enter a regular business relationship through the [Pierlis](http://pierlis.com/) company, based in Paris, France.


## Suggested Contributions

You'll find below various ideas for enhancing and extending GRDB, in various areas. Your ideas can be added to this list: [Suggest an Enhancement].

Legend:

- :baby: **Starter Task**: get familiar with GRDB internals
- :muscle: **Hard**: there are implementation challenges
- :pencil: **Documentation**
- :fire: **Experimental**: let's invent the future!
- :bowtie: **Public API Challenge**: we'll need a very good public API
- :hammer: **Tooling**: GRDB and its environment
- :question: **Unknown Difficulty**

The ideas, in alphabetical order:

- [Associations]
- [CloudKit]
- [Concurrency]
- [Custom FTS5 Auxiliary Functions]
- [Date and Time Functions]
- [Decode NSDecimalNumber from Text Columns]
- [Documentation]
- [Full Text Search Demo Application]
- [JSON]
- [Linux]
- [More SQL Generation]
- [Reactive Database Observation]
- [SQL Console in the Debugger]
- [SQLCipher in a Shared App Container]
- [Typed Expressions]


### Associations

:bowtie: Public API Challenge :muscle: Hard :fire: Experimental

Associations can be enhanced in several ways. See the "Known Issues" chapter of the [Associations Guide](Documentation/AssociationsBasics.md)


### CloudKit

:bowtie: Public API Challenge :question: Unknown Difficulty :fire: Experimental

Integration with [CloudKit](https://developer.apple.com/icloud/cloudkit/) is a rich, interesting, and useful topic.

It is likely that CloudKit support would exist in a separate companion library.

Starting points:

- [caiyue1993/IceCream](https://github.com/caiyue1993/IceCream)
- [mentrena/SyncKit](https://github.com/mentrena/SyncKit)
- [nofelmahmood/Seam](https://github.com/nofelmahmood/Seam)
- [Sorix/CloudCore](https://github.com/Sorix/CloudCore)
- [Synchronizing data with CloudKit](https://medium.com/@guilhermerambo/synchronizing-data-with-cloudkit-94c6246a3fda)
- WWDC CloudKit sessions, including [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2016/231/)


### Concurrency

:bowtie: Public API Challenge :muscle: Hard :pencil: Documentation

GRDB has a strong focus on safe concurrency. Not only safe as "does not crash", but safe as "actively protects your application data". The topic is discussed in (too) many places:

- [Concurrency Guide](README.md#concurrency)
- [Why Adopt GRDB?](https://github.com/groue/GRDB.swift/blob/master/Documentation/WhyAdoptGRDB.md#strong-and-clear-multi-threading-guarantees)
- [Four different ways to handle SQLite concurrency](https://medium.com/@gwendal.roue/four-different-ways-to-handle-sqlite-concurrency-db3bcc74d00e)
- [Good Practices for Designing Record Types](https://github.com/groue/GRDB.swift/blob/master/Documentation/GoodPracticesForDesigningRecordTypes.md#fetch-in-time)
- [Comparison between GRDB and Core Data concurrency](https://github.com/groue/GRDB.swift/issues/405)

Despite this abundant documention, I regularly meet developers who don't think about eventual multi-threading gotchas, and don't design their application against them.

This can be explained:

- Some developers disregard potential multi-threading bugs such as data races, even if the fix is "easy". Such bugs may never happen during the development of an application. They may only impact a few users in production. It is always easier not to think about them.

- Databases are often seen as plain CRUD tools, and some developers are not familiar with topics like isolation or transactions. This is especially true for developers who have experience in a managed ORM such as Core Data or Realm, or web frameworks like Rails or Django: switching to an unmanaged relational database is not an easy task.

- Not all applications need to be multi-threaded.

And this creates improvement opportunities:

- Better documentation of GRDB concurrency

- The introduction of an "ultra-safe" concurrency mode. Maybe something that restricts all database accesses to the main thread, like [FCModel](https://github.com/marcoarment/FCModel). Maybe in a separate companion library.


### Custom FTS5 Auxiliary Functions

:question: Unknown Difficulty

The SQLite documentation provides [this description](https://www.sqlite.org/fts5.html) of FTS5 auxiliary functions:

> An application may use FTS5 auxiliary functions to retrieve extra information regarding the matched row. For example, an auxiliary function may be used to retrieve a copy of a column value for a matched row with all instances of the matched term surrounded by html <b></b> tags.

Applications can define their own [custom FTS5 auxiliary functions](https://www.sqlite.org/fts5.html#custom_auxiliary_functions) with SQLite, but GRDB does not yet provide any Swift API for that.

See issue [#421](https://github.com/groue/GRDB.swift/issues/421) for more information.


### Date and Time Functions

:baby: Starter Task

Believe it or not, no one has ever asked support for SQLite [Date And Time Functions](https://www.sqlite.org/lang_datefunc.html). There is surely room for a nice Swift API that makes them available.

For more ideas, see:

- [SQLite Core Functions](https://www.sqlite.org/lang_corefunc.html)
- [SQLite Aggregate Functions](https://www.sqlite.org/lang_aggfunc.html)
- [SQLite JSON functions](https://www.sqlite.org/json1.html) and [JSON], below.

Functions are defined in [GRDB/QueryInterface/Support/SQLFunctions.swift](https://github.com/groue/GRDB.swift/blob/master/GRDB/QueryInterface/Support/SQLFunctions.swift).


### Decode NSDecimalNumber from Text Columns

:baby: Starter Task

NSDecimalNumber currently only decodes integer and float decimal values. It would be nice if NSDecimalNumber would decode text values as well:

```swift
let number = try NSDecimalNumber.fetchOne(db, "SELECT '12.3'")!
print(number) // prints 12.3
```

NSNumber and NSDecimalNumber support is found in [GRDB/Core/Support/Foundation/NSNumber.swift](https://github.com/groue/GRDB.swift/blob/master/GRDB/Core/Support/Foundation/NSNumber.swift)


### Documentation

:baby: Starter Task :pencil: Documentation

General documentation can always be improved so that it reaches its goal: helping developers building applications.

- English: the documentation has mostly been written by [@groue](http://github.com/groue) who is not a native English speaker.
- Clarity: any chapter that is not crystal clear should be enhanced.
- Audience: documentation should talk to several populations of developers, from beginners who need positive guidance, to SQLite experts who need to build trust.
- Typos
- Inaccuracies
- etc.

Inline documentation, the one which is embedded right into the source code and is displayed by Xcode when one alt-clicks an identifier, deserves the same care.

If you are a good writer, your help will be very warmly welcomed.


### Full Text Search Demo Application

:baby: Starter Task :pencil: Documentation

There exists a GRDB demo app for the FTS5 full-text engine: [WWDCCompanion](https://github.com/groue/WWDCCompanion).

This application downloads the transcripts of WWDC sessions, and lets its user type keywords and find matching sessions, sorted by relevance.

The problem is that this demo app breaks every year :sweat_smile:

We'd need instead to index a stable corpus, in order to ease the maintenance of this demo app.


### JSON

:bowtie: Public API Challenge :baby: Starter Task

[Codable Records] are granted with automatic JSON encoding and decoding of their complex properties. But there is still room for improvements. For example, could we put the [SQLite JSON1 extension](https://www.sqlite.org/json1.html) to some good use?


### Linux

:muscle: Hard :hammer: Tooling

Swift on Linux is currently focused on the server (Vapor, Perfect, Kitura). While general server support is a [non-goal](#non-goals) of GRDB, there exists read-only servers, and Linux GUI applications, too. Linux is thus a desired platform.


### More SQL Generation

:bowtie: Public API Challenge :question: Unknown Difficulty

There are several SQLite features that GRDB could natively support:

- [ALTER TABLE ... RENAME COLUMN ... TO ...](https://www.sqlite.org/lang_altertable.html)
- [ATTACH DATABASE](https://www.sqlite.org/lang_attach.html)
- [UPSERT](https://www.sqlite.org/lang_UPSERT.html)
- [INSERT INTO ... SELECT ...](https://www.sqlite.org/lang_insert.html)
- [WITH RECURSIVE ...](https://www.sqlite.org/lang_with.html)
- [RTree](https://sqlite.org/rtree.html)
- [Windows Functions](https://www.sqlite.org/windowfunctions.html)
- [More ideas](https://www.sqlite.org/lang.html)

See [issue #575](https://github.com/groue/GRDB.swift/issues/575) for more information and guidance about the implementation of extra table alterations.


### Reactive Database Observation

:baby: Starter Task

We already have the [GRDBCombine](http://github.com/groue/GRDBCombine) and [RxGRDB] companion libraries.

More choices of reactive engines would help more developers enjoy GRDB.


### SQL Console in the Debugger

:question: Unknown Difficulty :hammer: Tooling

Sometimes one needs, in lldb, a console similar to the [Command Line Shell For SQLite](https://www.sqlite.org/cli.html).


### SQLCipher in a Shared App Container

:question: Unknown Difficulty

See issue [#302](https://github.com/groue/GRDB.swift/issues/302).


### Typed Expressions

:bowtie: Public API Challenge :muscle: Hard :fire: Experimental

The compiler currently does not spot type mistakes in query interface requests:

```swift
Player.filter(Column("name") == "Arthur") // OK
Player.filter(Column("name") == 1)        // Sure
Player.filter(Column("name") == Date())   // Legit
```

This weak typing also prevents natural-looking Swift code from producing the expected results:

```swift
// Performs arithmetic additions instead of string concatenation
Player.select(Column("firstName") + " " + Column("lastName"))
```

It would be interesting to see what typed expressions could bring to GRDB.


## Non-Goals

GRDB is a "toolkit for SQLite databases, with a focus on application development".

This definition is the reason why GRDB can provide key features such as sharp multi-threading, database observation, and first-class support for raw SQL.

Features that blur this focus are non-goals:

- Support for MySQL, PostgreSQL, or other database engines
- Support for Servers


[Ask Questions]: #ask-questions
[Associations]: #associations
[CloudKit]: #cloudkit
[Codable Records]: README.md#codable-records
[Custom FTS5 Auxiliary Functions]: #custom-fts5-auxiliary-functions
[Database Observation]: #database-observation
[Date and Time Functions]: #date-and-time-functions
[Decode NSDecimalNumber from Text Columns]: #decode-nsdecimalnumber-from-text-columns
[Documentation]: #documentation
[Full Text Search Demo Application]: #full-text-search-demo-application
[How is the Library Organized?]: Documentation/LibraryOrganization.md
[How is the Repository Organized?]: Documentation/RepositoryOrganization.md
[JSON]: #json
[Linux]: #linux
[More SQL Generation]: #more-sql-generation
[Reactive Database Observation]: #reactive-database-observation
[Records: Splitting Database Encoding from Ability to Write in the Database]: #records-splitting-database-encoding-from-ability-to-write-in-the-database
[Non-Goals]: #non-goals
[Report Bugs]: #report-bugs
[RxGRDB]: http://github.com/RxSwiftCommunity/RxGRDB
[Concurrency]: #concurrency
[Sponsoring and Professional Support]: #sponsoring-and-professional-support
[SQL Console in the Debugger]: #sql-console-in-the-debugger
[SQLCipher in a Shared App Container]: #sqlcipher-in-a-shared-app-container
[Submit a Pull Request]: #submit-a-pull-request
[Suggest an Enhancement]: #suggest-an-enhancement
[Suggested Contributions]: #suggested-contributions
[Typed Expressions]: #typed-expressions
[persistence methods]: README.md#persistence-methods
[PersistableRecord]: README.md#persistablerecord-protocol
[Record Comparison]: README.md#record-comparison
[Requesting Associated Records]: Documentation/AssociationsBasics.md#requesting-associated-records
[ValueObservation]: README.md#valueobservation
