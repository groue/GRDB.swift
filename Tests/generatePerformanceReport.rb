#!/usr/bin/env ruby
gem 'json'
require 'json'
require 'date'
require 'rexml/document'

# Extract CFBundleShortVersionString from a plist file
def info_plist_version(path)
  REXML::Document.new(File.read(path))
    .root
    .elements["//key[text()='CFBundleShortVersionString']"]
    .next_element
    .text
end

def git_tag_version(path)
  `git -C #{path} tag --points-at HEAD`.chop.gsub(/^v?/, '')
end

def formatted_sample(samples, test, lib)
  sample = samples["#{test}Tests"]["test#{lib}"]
  return '¹' unless sample # n/a
  '%.2f' % sample
end

def formatted_samples(samples, test)
  libs = %w{GRDB SQLite FMDB SQLiteSwift CoreData Realm}
  libs.map { |lib| formatted_sample(samples, test, lib) || '¹' }
end

# Parse input
samples = JSON.parse(STDIN.read)

# Now that we have samples, we are reasonably sure that we 
# have checkouts for all dependencies.

# BUILD_ROOT
exit 1 unless `xcodebuild -showBuildSettings -project Tests/Performance/GRDBPerformance/GRDBPerformance.xcodeproj -scheme GRDBOSXPerformanceComparisonTests -disableAutomaticPackageResolution` =~ /BUILD_ROOT = (.*)$/
BUILD_ROOT = $1

# DERIVED_DATA
tmp = BUILD_ROOT
while !File.exist?(File.join(tmp, 'SourcePackages'))
  parent = File.dirname(tmp)
  exit 1 if tmp == parent
  tmp = parent
end
DERIVED_DATA = tmp

# SPM_CHECKOUTS
SPM_CHECKOUTS = File.join(DERIVED_DATA, 'SourcePackages', 'checkouts')

# Extract versions
GRDB_VERSION = info_plist_version('Support/Info.plist')
FMDB_VERSION = info_plist_version("#{SPM_CHECKOUTS}/fmdb/src/fmdb/Info.plist")
SQLITE_SWIFT_VERSION = git_tag_version("#{SPM_CHECKOUTS}/SQLite.swift")
REALM_VERSION = git_tag_version("#{SPM_CHECKOUTS}/realm-swift")

`xcodebuild -version` =~ /Xcode (.*)$/
XCODE_VERSION = $1

# Hardware name: https://apple.stackexchange.com/a/98089
`curl -s https://support-sp.apple.com/sp/product?cc=$(
  system_profiler SPHardwareDataType \
  | awk '/Serial/ {print $4}' \
  | cut -c 9-)` =~ /<configCode>(.*)<\/configCode>/
hardware = $1
if hardware
  HARDWARE = hardware
else
  # in case the previous technique does not work
  HARDWARE = `system_profiler SPHardwareDataType | awk '/Model Identifier/ {print $3}'`.chomp
end

STDERR.puts "GRDB_VERSION: #{GRDB_VERSION}"
STDERR.puts "FMDB_VERSION: #{FMDB_VERSION}"
STDERR.puts "SQLITE_SWIFT_VERSION: #{SQLITE_SWIFT_VERSION}"
STDERR.puts "REALM_VERSION: #{REALM_VERSION}"
STDERR.puts "XCODE_VERSION: #{XCODE_VERSION}"
STDERR.puts "HARDWARE: #{HARDWARE}"

# Generate
puts <<-REPORT
# Comparing the Performances of Swift SQLite libraries

*Last updated #{Date.today.strftime('%B %-d, %Y')}*

Below are performance benchmarks made on for [GRDB #{GRDB_VERSION}](https://github.com/groue/GRDB.swift), [FMDB #{FMDB_VERSION}](https://github.com/ccgus/fmdb), and [SQLite.swift #{SQLITE_SWIFT_VERSION}](https://github.com/stephencelis/SQLite.swift). They are compared to Core Data, [Realm #{REALM_VERSION}](https://realm.io) and the raw use of the SQLite C API from Swift.

This report was generated on a #{HARDWARE}, with Xcode #{XCODE_VERSION}, by running the following command:

```sh
make test_performance | Tests/parsePerformanceTests.rb | Tests/generatePerformanceReport.rb
```

All tests use the default settings of each library. For each library, we:

- Build and consume database rows with raw SQL and column indexes (aiming at the best performance)
- Build and consume database rows with column names (sacrificing performance for maintainability)
- Build and consume records values to and from database rows (aiming at the shortest code from database to records)
- Build and consume records values to and from database rows, with help from the Codable standard protocol
- Build and consume records values to and from database rows, with [change tracking](https://github.com/groue/GRDB.swift/blob/master/README.md#record-comparison) (records know if they have unsaved changes)

As a bottom line, the raw SQLite C API is used as efficiently as possible, without any error checking.

|                                  | GRDB | Raw SQLite | FMDB | SQLite.swift | Core Data | Realm |
|:-------------------------------- | ----:| ----------:| ----:| ------------:| ---------:| -----:|
| **Column indexes**               |      |            |      |              |           |       |
| Fetch                            | #{formatted_samples(samples, 'FetchPositionalValues').join(" | ")} |
| Insert                           | #{formatted_samples(samples, 'InsertPositionalValues').join(" | ")} |
| **Column names**                 |      |            |      |              |           |       |
| Fetch                            | #{formatted_samples(samples, 'FetchNamedValues').join(" | ")} |
| Insert                           | #{formatted_samples(samples, 'InsertNamedValues').join(" | ")} |
| **Records**                      |      |            |      |              |           |       |
| Fetch                            | #{formatted_samples(samples, 'FetchRecordStruct').join(" | ")} |
| Insert                           | #{formatted_samples(samples, 'InsertRecordStruct').join(" | ")} |
| **Codable Records**              |      |            |      |              |           |       |
| Fetch                            | #{formatted_samples(samples, 'FetchRecordDecodable').join(" | ")} |
| Insert                           | #{formatted_samples(samples, 'InsertRecordEncodable').join(" | ")} |
| **Optimized Records**            |      |            |      |              |           |       |
| Fetch                            | #{formatted_samples(samples, 'FetchRecordOptimized').join(" | ")} |
| Insert                           | #{formatted_samples(samples, 'InsertRecordOptimized').join(" | ")} |
| **Records with change tracking** |      |            |      |              |           |       |
| Fetch                            | #{formatted_samples(samples, 'FetchRecordClass').join(" | ")} |
| Insert                           | #{formatted_samples(samples, 'InsertRecordClass').join(" | ")} |

¹ Not applicable

- **Column indexes**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/FetchPositionalValuesTests.swift))
        
        This test fetches 200000 rows of 10 ints and extracts each int given its position in the row.
        
        It uses FMDB's `-[FMResultSet longForColumnIndex:]`, GRDB's `Row.value(atIndex:)`, and the low-level SQL API of SQLite.swift.
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/InsertPositionalValuesTests.swift))
        
        This test inserts 50000 rows of 10 ints, by setting query arguments given their position.
        
        It uses FMDB's `-[FMDatabase executeUpdate:withArgumentsInArray:]` with statement caching, GRDB's `UpdateStatement.execute(arguments:Array)`, and the low-level SQL API of SQLite.swift.

- **Column names**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/FetchNamedValuesTests.swift))
        
        This test fetches 200000 rows of 10 ints and extracts each int given its column name.
        
        It uses FMDB's `-[FMResultSet longForColumn:]`, GRDB's `Row.value(named:)`, and the high-level query builder of SQLite.swift.
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/InsertNamedValuesTests.swift))
        
        This test inserts 50000 rows of 10 ints, by setting query arguments given their argument name.
        
        It uses FMDB's `-[FMDatabase executeUpdate:withParameterDictionary:]` with statement caching, GRDB's `UpdateStatement.execute(arguments:Dictionary)`, and the high-level query builder of SQLite.swift.

- **Records**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/FetchRecordStructTests.swift))
        
        This test fetches an array of 200000 record objects initiated from rows of 10 ints.
        
        It builds records from FMDB's `-[FMResultSet resultDictionary]`, GRDB's built-in [FetchableRecord](https://github.com/groue/GRDB.swift/blob/master/README.md#fetchablerecord-protocol) protocol, and the values returned by the high-level query builder of SQLite.swift.
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/InsertRecordStructTests.swift))
        
        This tests inserts 50000 records with the persistence method provided by GRDB's [PersistableRecord](https://github.com/groue/GRDB.swift/blob/master/README.md#persistablerecord-protocol) protocol.

- **Codable Records**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/FetchRecordDecodableTests.swift))
        
        This test fetches an array of 200000 record objects initiated from rows of 10 ints.
        
        It builds records from GRDB's built-in support for the [Decodable standard protocols](https://github.com/groue/GRDB.swift/blob/master/README.md#codable-records).
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/InsertRecordEncodableTests.swift))
        
        This tests inserts 50000 records with the persistence method provided by GRDB's built-in support for the [Encodable standard protocols](https://github.com/groue/GRDB.swift/blob/master/README.md#codable-records).

- **Optimized Records**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/FetchRecordDecodableTests.swift))
        
        This test shows how to optimize Decodable Records for fetching.
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/InsertRecordEncodableTests.swift))
        
        This test shows how to optimize Encodable Records for batch inserts.

- **Records with change tracking**:

    - **Fetch** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/FetchRecordClassTests.swift))
        
        This test fetches an array of 200000 record objects initiated from rows of 10 ints.
        
        It builds records from FMDB's `-[FMResultSet resultDictionary]`, GRDB's built-in [Record](https://github.com/groue/GRDB.swift/blob/master/README.md#record-class) class.
    
    - **Insert** ([source](https://github.com/groue/GRDB.swift/blob/master/Tests/Performance/GRDBPerformance/InsertRecordClassTests.swift))
        
        This tests inserts 50000 records with the persistence method provided by GRDB's [Record](https://github.com/groue/GRDB.swift/blob/master/README.md#record-class) class.
REPORT
