#!/usr/bin/env ruby
gem 'json'
require 'json'
require 'date'

tests = JSON.parse(STDIN.read)

puts <<-REPORT
# Comparing the Performances of Swift SQLite libraries

*Last updated #{Date.today.strftime('%B %-d, %Y')}*

Below are performance benchmarks made on for [GRDB 2.4.1](https://github.com/groue/GRDB.swift), [FMDB 2.7.4](https://github.com/ccgus/fmdb), and [SQLite.swift 0.11.4](https://github.com/stephencelis/SQLite.swift). They are compared to Core Data, [Realm 3.0.2](https://realm.io) and the raw use of the SQLite C API from Swift.

This report was generated on a MacBook Pro (15-inch, Late 2016), with Xcode 9.2, by running the following command:

```sh
make test_performance | Tests/parsePerformanceTests.rb | Tests/generatePerformanceReport.rb
```

All tests use the default settings of each library. For each library, we:

- Build and consume database rows with raw SQL and column indexes (aiming at the best performance)
- Build and consume database rows with column names (sacrificing performance for maintainability)
- Build and consume records values to and from database rows (aiming at the shortest code from database to records)
- Build and consume records values to and from database rows, with [change tracking](https://github.com/groue/GRDB.swift#changes-tracking) (records know if they have unsaved changes)

As a bottom line, the raw SQLite C API is used as efficiently as possible, without any error checking.

|                    | Raw SQLite |     FMDB |      GRDB| SQLite.swift |  Core Data | Realm |
|:------------------ | ----------:| --------:| --------:| ------------:| ----------:| -----:|
| **Column indexes** |            |          |          |              |            |       |
| Fetch              | *#{tests['FetchPositionalValuesTests']['testSQLite']}* | **#{tests['FetchPositionalValuesTests']['testFMDB']}** | **#{tests['FetchPositionalValuesTests']['testGRDB']}** | #{tests['FetchPositionalValuesTests']['testSQLiteSwift']} | ¹ | ¹ |
| Insert             | *#{tests['InsertPositionalValuesTests']['testSQLite']}* | #{tests['InsertPositionalValuesTests']['testFMDB']} | **#{tests['InsertPositionalValuesTests']['testGRDB']}** | #{tests['InsertPositionalValuesTests']['testSQLiteSwift']} | ¹ | ¹ |
| **Column names**   |            |          |          |              |            |       |
| Fetch              |          ¹ | #{tests['FetchNamedValuesTests']['testFMDB']} | **#{tests['FetchNamedValuesTests']['testGRDB']}** | #{tests['FetchNamedValuesTests']['testSQLiteSwift']} | ¹ | ¹ |
| Insert             |          ¹ | #{tests['InsertNamedValuesTests']['testFMDB']} | **#{tests['InsertNamedValuesTests']['testGRDB']}** | #{tests['InsertNamedValuesTests']['testSQLiteSwift']} | ¹ | ¹ |
| **Records**        |            |          |          |              |            |       |
| Fetch              | *#{tests['FetchRecordStructTests']['testSQLite']}* | #{tests['FetchRecordStructTests']['testFMDB']} | **#{tests['FetchRecordStructTests']['testGRDB']}** | #{tests['FetchRecordStructTests']['testSQLiteSwift']} | ¹ | ¹ |
| Insert             |          ¹ |        ¹ | **#{tests['InsertRecordStructTests']['testGRDB']}** | ¹ | ¹ | ¹ |
| **Records with change tracking** | |       |          |              |            |       |
| Fetch              |          ¹ |        ¹ | **#{tests['FetchRecordClassTests']['testGRDB']}** | ¹ | #{tests['FetchRecordClassTests']['testCoreData']} | #{tests['FetchRecordClassTests']['testRealm']} |
| Insert             |          ¹ |        ¹ | **#{tests['InsertRecordClassTests']['testGRDB']}** | ¹ | #{tests['InsertRecordClassTests']['testCoreData']} | #{tests['InsertRecordClassTests']['testRealm']} |

¹ Not applicable

- **Column indexes**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/FetchPositionalValuesTests.swift))
        
        This test fetches 100000 rows of 10 ints and extracts each int given its position in the row.
        
        It uses FMDB's `-[FMResultSet longForColumnIndex:]`, GRDB's `Row.value(atIndex:)`, and the low-level SQL API of SQLite.swift.
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/InsertPositionalValuesTests.swift))
        
        This test inserts 20000 rows of 10 ints, by setting query arguments given their position.
        
        It uses FMDB's `-[FMDatabase executeUpdate:withArgumentsInArray:]` with statement caching, GRDB's `UpdateStatement.execute(arguments:Array)`, and the low-level SQL API of SQLite.swift.

- **Column names**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/FetchNamedValuesTests.swift))
        
        This test fetches 100000 rows of 10 ints and extracts each int given its column name.
        
        It uses FMDB's `-[FMResultSet longForColumn:]`, GRDB's `Row.value(named:)`, and the high-level query builder of SQLite.swift.
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/InsertNamedValuesTests.swift))
        
        This test inserts 20000 rows of 10 ints, by setting query arguments given their argument name.
        
        It uses FMDB's `-[FMDatabase executeUpdate:withParameterDictionary:]` with statement caching, GRDB's `UpdateStatement.execute(arguments:Dictionary)`, and the high-level query builder of SQLite.swift.

- **Records**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/FetchRecordStructTests.swift))
        
        This test fetches an array of 100000 record objects initiated from rows of 10 ints.
        
        It builds records from FMDB's `-[FMResultSet resultDictionary]`, GRDB's built-in [RowConvertible](https://github.com/groue/GRDB.swift#rowconvertible-protocol) protocol, and the values returned by the high-level query builder of SQLite.swift.
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/InsertRecordStructTests.swift))
        
        This tests inserts 20000 records with the persistence method provided by GRDB's [Persistable](https://github.com/groue/GRDB.swift#persistable-protocol) protocol.

- **Records with change tracking**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/FetchRecordClassTests.swift))
        
        This test fetches an array of 100000 record objects initiated from rows of 10 ints.
        
        It builds records from FMDB's `-[FMResultSet resultDictionary]`, GRDB's built-in [Record](https://github.com/groue/GRDB.swift#record-class) class.
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/InsertRecordClassTests.swift))
        
        This tests inserts 20000 records with the persistence method provided by GRDB's [Record](https://github.com/groue/GRDB.swift#record-class) class.
REPORT
