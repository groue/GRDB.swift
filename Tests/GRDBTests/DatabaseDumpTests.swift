import XCTest
import GRDB

private final class TestStream: TextOutputStream {
    var output: String
    
    init() {
        output = ""
    }
    
    func write(_ string: String) {
        output.append(string)
    }
}

private struct Player: Codable, MutablePersistableRecord {
    static let team = belongsTo(Team.self)
    var id: Int64?
    var name: String
    var teamId: String?
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

private struct Team: Codable, PersistableRecord {
    static let players = hasMany(Player.self)
    var id: String
    var name: String
    var color: String
}

final class DatabaseDumpTests: GRDBTestCase {
    // MARK: - Debug
    
    func test_debug_value_formatting() throws {
        try makeValuesDatabase().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT * FROM value ORDER BY name", format: .debug(), to: stream)
            XCTAssertEqual(stream.output, """
                blob: ascii apostrophe|[']
                blob: ascii double quote|["]
                blob: ascii line feed|[
                ]
                blob: ascii long|Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus.
                blob: ascii short|Hello
                blob: ascii tab|[\t]
                blob: binary short|X'80'
                blob: empty|
                blob: utf8 short|您好🙂
                blob: uuid|69BF8A9C-D9F0-4777-BD11-93451D84CBCF
                double: -1.0|-1.0
                double: -inf|-inf
                double: 0.0|0.0
                double: 123.45|123.45
                double: inf|inf
                double: nan|
                integer: -1|-1
                integer: 0|0
                integer: 123|123
                integer: max|9223372036854775807
                integer: min|-9223372036854775808
                null|
                text: ascii apostrophe|[']
                text: ascii backslash|[\\]
                text: ascii double quote|["]
                text: ascii line feed|[
                ]
                text: ascii long|Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus.
                text: ascii short|Hello
                text: ascii slash|[/]
                text: ascii tab|[\t]
                text: ascii url|https://github.com/groue/GRDB.swift
                text: empty|
                text: utf8 short|您好🙂
                
                """)
        }
    }
    
    func test_debug_empty_results() throws {
        try makeDatabaseQueue().write { db in
            do {
                // Columns
                let stream = TestStream()
                try db.dumpSQL("SELECT NULL WHERE NULL", format: .debug(), to: stream)
                XCTAssertEqual(stream.output, "")
            }
            do {
                // No columns
                let stream = TestStream()
                try db.dumpSQL("CREATE TABLE t(a)", format: .debug(), to: stream)
                XCTAssertEqual(stream.output, "")
            }
        }
    }
    
    func test_debug_headers() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Headers on
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .debug(header: true), to: stream)
                XCTAssertEqual(stream.output, """
                    id|teamId|name
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Headers on, no result
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player WHERE 0", format: .debug(header: true), to: stream)
                XCTAssertEqual(stream.output, "")
            }
            do {
                // Headers off
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .debug(header: false), to: stream)
                XCTAssertEqual(stream.output, """
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Headers off, no result
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player WHERE 0", format: .debug(header: false), to: stream)
                XCTAssertEqual(stream.output, "")
            }
        }
    }
    
    func test_debug_duplicate_columns() throws {
        try makeDatabaseQueue().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT 1 AS name, 'foo' AS name", format: .debug(header: true), to: stream)
            XCTAssertEqual(stream.output, """
                name|name
                1|foo
                
                """)
        }
    }
    
    func test_debug_multiple_statements() throws {
        try makeDatabaseQueue().write { db in
            let stream = TestStream()
            try db.dumpSQL(
                """
                CREATE TABLE t(a, b);
                INSERT INTO t VALUES (1, 'foo');
                INSERT INTO t VALUES (2, 'bar');
                SELECT * FROM t ORDER BY a;
                SELECT b FROM t ORDER BY b;
                SELECT NULL WHERE NULL;
                """,
                format: .debug(),
                to: stream)
            XCTAssertEqual(stream.output, """
                1|foo
                2|bar
                bar
                foo
                
                """)
        }
    }
    
    func test_debug_separator() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default separator
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .debug(header: true), to: stream)
                XCTAssertEqual(stream.output, """
                    id|teamId|name
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Custom separator
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .debug(header: true, separator: "---"), to: stream)
                XCTAssertEqual(stream.output, """
                    id---teamId---name
                    1---FRA---Antoine Dupond
                    2---ENG---Owen Farrell
                    3------Gwendal Roué
                    
                    """)
            }
        }
    }
    
    func test_debug_nullValue() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default null
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .debug(), to: stream)
                XCTAssertEqual(stream.output, """
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Custom null
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .debug(nullValue: "NULL"), to: stream)
                XCTAssertEqual(stream.output, """
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3|NULL|Gwendal Roué
                    
                    """)
            }
        }
    }
    
    // MARK: - JSON
    
    func test_json_value_formatting() throws {
        guard #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) else {
            throw XCTSkip("Skip because this test relies on JSONEncoder.OutputFormatting.withoutEscapingSlashes")
        }
        
        try makeValuesDatabase().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT * FROM value ORDER BY name", format: .json(), to: stream)
            XCTAssertEqual(stream.output, """
                [{"name":"blob: ascii apostrophe","value":"Wydd"},
                {"name":"blob: ascii double quote","value":"WyJd"},
                {"name":"blob: ascii line feed","value":"Wwpd"},
                {"name":"blob: ascii long","value":"TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdC4gTW9yYmkgdHJpc3RpcXVlIHRlbXBvciBjb25kaW1lbnR1bS4gUGVsbGVudGVzcXVlIHBoYXJldHJhIGxhY3VzIG5vbiBhbnRlIHNvbGxpY2l0dWRpbiBhdWN0b3IuIFZlc3RpYnVsdW0gc2l0IGFtZXQgbWF1cmlzIHZpdGFlIHVybmEgbm9uIGx1Y3R1cy4="},
                {"name":"blob: ascii short","value":"SGVsbG8="},
                {"name":"blob: ascii tab","value":"Wwld"},
                {"name":"blob: binary short","value":"gA=="},
                {"name":"blob: empty","value":""},
                {"name":"blob: utf8 short","value":"5oKo5aW98J+Zgg=="},
                {"name":"blob: uuid","value":"ab+KnNnwR3e9EZNFHYTLzw=="},
                {"name":"double: -1.0","value":-1},
                {"name":"double: -inf","value":"-inf"},
                {"name":"double: 0.0","value":0},
                {"name":"double: 123.45","value":123.45},
                {"name":"double: inf","value":"inf"},
                {"name":"double: nan","value":null},
                {"name":"integer: -1","value":-1},
                {"name":"integer: 0","value":0},
                {"name":"integer: 123","value":123},
                {"name":"integer: max","value":9223372036854775807},
                {"name":"integer: min","value":-9223372036854775808},
                {"name":"null","value":null},
                {"name":"text: ascii apostrophe","value":"[']"},
                {"name":"text: ascii backslash","value":"[\\\\]"},
                {"name":"text: ascii double quote","value":"[\\"]"},
                {"name":"text: ascii line feed","value":"[\\n]"},
                {"name":"text: ascii long","value":"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus."},
                {"name":"text: ascii short","value":"Hello"},
                {"name":"text: ascii slash","value":"[/]"},
                {"name":"text: ascii tab","value":"[\\t]"},
                {"name":"text: ascii url","value":"https://github.com/groue/GRDB.swift"},
                {"name":"text: empty","value":""},
                {"name":"text: utf8 short","value":"您好🙂"}]
                
                """)
        }
    }
    
    func test_json_empty_results() throws {
        try makeDatabaseQueue().write { db in
            do {
                // Columns
                let stream = TestStream()
                try db.dumpSQL("SELECT NULL WHERE NULL", format: .json(), to: stream)
                XCTAssertEqual(stream.output, """
                    []
                    
                    """)
            }
            do {
                // No columns
                let stream = TestStream()
                try db.dumpSQL("CREATE TABLE t(a)", format: .json(), to: stream)
                XCTAssertEqual(stream.output, "")
            }
        }
    }
    
    func test_json_duplicate_columns() throws {
        try makeDatabaseQueue().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT 1 AS name, 'foo' AS name", format: .json(), to: stream)
            XCTAssertEqual(stream.output, """
                [{"name":1,"name":"foo"}]
                
                """)
        }
    }
    
    func test_json_multiple_statements() throws {
        try makeDatabaseQueue().write { db in
            let stream = TestStream()
            try db.dumpSQL(
                """
                CREATE TABLE t(a, b);
                INSERT INTO t VALUES (1, 'foo');
                INSERT INTO t VALUES (2, 'bar');
                SELECT * FROM t ORDER BY a;
                SELECT b FROM t ORDER BY b;
                SELECT NULL WHERE NULL;
                """,
                format: .json(),
                to: stream)
            XCTAssertEqual(stream.output, """
                [{"a":1,"b":"foo"},
                {"a":2,"b":"bar"}]
                [{"b":"bar"},
                {"b":"foo"}]
                []
                
                """)
        }
    }
    
    func test_json_custom_encoder() throws {
        try makeDatabaseQueue().write { db in
            try db.execute(literal: """
                CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT, value DOUBLE);
                INSERT INTO t VALUES (1, 'a', 0.0);
                INSERT INTO t VALUES (2, 'b', \(1.0 / 0));
                INSERT INTO t VALUES (3, 'c', \(-1.0 / 0));
                """)
            let encoder = JSONDumpFormat.defaultEncoder
            encoder.nonConformingFloatEncodingStrategy = .convertToString(
                positiveInfinity: "much too much",
                negativeInfinity: "whoops",
                nan: "")
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys /* ignored */]
            let stream = TestStream()
            try db.dumpSQL("SELECT * FROM t ORDER BY id", format: .json(encoder: encoder), to: stream)
            XCTAssertEqual(stream.output, """
                [
                  {
                    "id":1,
                    "name":"a",
                    "value":0
                  },
                  {
                    "id":2,
                    "name":"b",
                    "value":"much too much"
                  },
                  {
                    "id":3,
                    "name":"c",
                    "value":"whoops"
                  }
                ]
                
                """)
        }
    }
    
    // MARK: - Line
    
    func test_line_value_formatting() throws {
        try makeValuesDatabase().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT * FROM value ORDER BY name", format: .line(), to: stream)
            XCTAssertEqual(stream.output, """
                 name = blob: ascii apostrophe
                value = [']
                
                 name = blob: ascii double quote
                value = ["]
                
                 name = blob: ascii line feed
                value = [
                ]
                
                 name = blob: ascii long
                value = Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus.
                
                 name = blob: ascii short
                value = Hello
                
                 name = blob: ascii tab
                value = [\t]
                
                 name = blob: binary short
                value = �
                
                 name = blob: empty
                value = \n\
                
                 name = blob: utf8 short
                value = 您好🙂
                
                 name = blob: uuid
                value = \("i\u{fffd}\u{fffd}\u{fffd}\u{fffd}\u{fffd}Gw\u{fffd}\u{11}\u{fffd}E\u{1d}\u{fffd}\u{fffd}\u{fffd}")
                
                 name = double: -1.0
                value = -1.0
                
                 name = double: -inf
                value = -inf
                
                 name = double: 0.0
                value = 0.0
                
                 name = double: 123.45
                value = 123.45
                
                 name = double: inf
                value = inf
                
                 name = double: nan
                value = \n\
                
                 name = integer: -1
                value = -1
                
                 name = integer: 0
                value = 0
                
                 name = integer: 123
                value = 123
                
                 name = integer: max
                value = 9223372036854775807
                
                 name = integer: min
                value = -9223372036854775808
                
                 name = null
                value = \n\
                
                 name = text: ascii apostrophe
                value = [']
                
                 name = text: ascii backslash
                value = [\\]
                
                 name = text: ascii double quote
                value = ["]
                
                 name = text: ascii line feed
                value = [
                ]
                
                 name = text: ascii long
                value = Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus.
                
                 name = text: ascii short
                value = Hello
                
                 name = text: ascii slash
                value = [/]
                
                 name = text: ascii tab
                value = [\t]
                
                 name = text: ascii url
                value = https://github.com/groue/GRDB.swift
                
                 name = text: empty
                value = \n\
                
                 name = text: utf8 short
                value = 您好🙂
                
                """)
        }
    }
    
    func test_line_empty_results() throws {
        try makeDatabaseQueue().write { db in
            do {
                // Columns
                let stream = TestStream()
                try db.dumpSQL("SELECT NULL WHERE NULL", format: .line(), to: stream)
                XCTAssertEqual(stream.output, "")
            }
            do {
                // No columns
                let stream = TestStream()
                try db.dumpSQL("CREATE TABLE t(a)", format: .line(), to: stream)
                XCTAssertEqual(stream.output, "")
            }
        }
    }
    
    func test_line_duplicate_columns() throws {
        try makeDatabaseQueue().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT 1 AS name, 'foo' AS name", format: .line(), to: stream)
            XCTAssertEqual(stream.output, """
                name = 1
                name = foo
                
                """)
        }
    }
    
    func test_line_multiple_statements() throws {
        try makeDatabaseQueue().write { db in
            let stream = TestStream()
            try db.dumpSQL(
                """
                CREATE TABLE t(a, b);
                INSERT INTO t VALUES (1, 'foo');
                INSERT INTO t VALUES (2, 'bar');
                SELECT * FROM t ORDER BY a;
                SELECT b FROM t ORDER BY b;
                SELECT NULL WHERE NULL;
                """,
                format: .line(),
                to: stream)
            XCTAssertEqual(stream.output, """
                a = 1
                b = foo
                
                a = 2
                b = bar
                
                b = bar
                
                b = foo
                
                """)
        }
    }
    
    func test_line_nullValue() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default null
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .line(), to: stream)
                XCTAssertEqual(stream.output, """
                        id = 1
                    teamId = FRA
                      name = Antoine Dupond
                    
                        id = 2
                    teamId = ENG
                      name = Owen Farrell
                    
                        id = 3
                    teamId = \n\
                      name = Gwendal Roué
                    
                    """)
            }
            do {
                // Custom null
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .line(nullValue: "NULL"), to: stream)
                XCTAssertEqual(stream.output, """
                        id = 1
                    teamId = FRA
                      name = Antoine Dupond
                    
                        id = 2
                    teamId = ENG
                      name = Owen Farrell
                    
                        id = 3
                    teamId = NULL
                      name = Gwendal Roué
                    
                    """)
            }
        }
    }
    
    // MARK: - List
    
    func test_list_value_formatting() throws {
        try makeValuesDatabase().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT * FROM value ORDER BY name", format: .list(), to: stream)
            XCTAssertEqual(stream.output, """
                blob: ascii apostrophe|[']
                blob: ascii double quote|["]
                blob: ascii line feed|[
                ]
                blob: ascii long|Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus.
                blob: ascii short|Hello
                blob: ascii tab|[\t]
                blob: binary short|�
                blob: empty|
                blob: utf8 short|您好🙂
                blob: uuid|\("i\u{fffd}\u{fffd}\u{fffd}\u{fffd}\u{fffd}Gw\u{fffd}\u{11}\u{fffd}E\u{1d}\u{fffd}\u{fffd}\u{fffd}")
                double: -1.0|-1.0
                double: -inf|-inf
                double: 0.0|0.0
                double: 123.45|123.45
                double: inf|inf
                double: nan|
                integer: -1|-1
                integer: 0|0
                integer: 123|123
                integer: max|9223372036854775807
                integer: min|-9223372036854775808
                null|
                text: ascii apostrophe|[']
                text: ascii backslash|[\\]
                text: ascii double quote|["]
                text: ascii line feed|[
                ]
                text: ascii long|Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus.
                text: ascii short|Hello
                text: ascii slash|[/]
                text: ascii tab|[\t]
                text: ascii url|https://github.com/groue/GRDB.swift
                text: empty|
                text: utf8 short|您好🙂
                
                """)
        }
    }
    
    func test_list_empty_results() throws {
        try makeDatabaseQueue().write { db in
            do {
                // Columns
                let stream = TestStream()
                try db.dumpSQL("SELECT NULL WHERE NULL", format: .list(), to: stream)
                XCTAssertEqual(stream.output, "")
            }
            do {
                // No columns
                let stream = TestStream()
                try db.dumpSQL("CREATE TABLE t(a)", format: .list(), to: stream)
                XCTAssertEqual(stream.output, "")
            }
        }
    }
    
    func test_list_headers() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Headers on
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .list(header: true), to: stream)
                XCTAssertEqual(stream.output, """
                    id|teamId|name
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Headers on, no result
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player WHERE 0", format: .list(header: true), to: stream)
                XCTAssertEqual(stream.output, "")
            }
            do {
                // Headers off
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .list(header: false), to: stream)
                XCTAssertEqual(stream.output, """
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Headers off, no result
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player WHERE 0", format: .list(header: false), to: stream)
                XCTAssertEqual(stream.output, "")
            }
        }
    }
    
    func test_list_duplicate_columns() throws {
        try makeDatabaseQueue().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT 1 AS name, 'foo' AS name", format: .list(header: true), to: stream)
            XCTAssertEqual(stream.output, """
                name|name
                1|foo
                
                """)
        }
    }
    
    func test_list_multiple_statements() throws {
        try makeDatabaseQueue().write { db in
            let stream = TestStream()
            try db.dumpSQL(
                """
                CREATE TABLE t(a, b);
                INSERT INTO t VALUES (1, 'foo');
                INSERT INTO t VALUES (2, 'bar');
                SELECT * FROM t ORDER BY a;
                SELECT b FROM t ORDER BY b;
                SELECT NULL WHERE NULL;
                """,
                format: .list(),
                to: stream)
            XCTAssertEqual(stream.output, """
                1|foo
                2|bar
                bar
                foo
                
                """)
        }
    }
    
    func test_list_separator() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default separator
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .list(header: true), to: stream)
                XCTAssertEqual(stream.output, """
                    id|teamId|name
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Custom separator
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .list(header: true, separator: "---"), to: stream)
                XCTAssertEqual(stream.output, """
                    id---teamId---name
                    1---FRA---Antoine Dupond
                    2---ENG---Owen Farrell
                    3------Gwendal Roué
                    
                    """)
            }
        }
    }
    
    func test_list_nullValue() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default null
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .list(), to: stream)
                XCTAssertEqual(stream.output, """
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Custom null
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .list(nullValue: "NULL"), to: stream)
                XCTAssertEqual(stream.output, """
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3|NULL|Gwendal Roué
                    
                    """)
            }
        }
    }
    
    // MARK: - Quote
    
    func test_quote_value_formatting() throws {
        try makeValuesDatabase().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT * FROM value ORDER BY name", format: .quote(), to: stream)
            XCTAssertEqual(stream.output, """
                'blob: ascii apostrophe',X'5B275D'
                'blob: ascii double quote',X'5B225D'
                'blob: ascii line feed',X'5B0A5D'
                'blob: ascii long',X'4C6F72656D20697073756D20646F6C6F722073697420616D65742C20636F6E73656374657475722061646970697363696E6720656C69742E204D6F726269207472697374697175652074656D706F7220636F6E64696D656E74756D2E2050656C6C656E746573717565207068617265747261206C61637573206E6F6E20616E746520736F6C6C696369747564696E20617563746F722E20566573746962756C756D2073697420616D6574206D61757269732076697461652075726E61206E6F6E206C75637475732E'
                'blob: ascii short',X'48656C6C6F'
                'blob: ascii tab',X'5B095D'
                'blob: binary short',X'80'
                'blob: empty',X''
                'blob: utf8 short',X'E682A8E5A5BDF09F9982'
                'blob: uuid',X'69BF8A9CD9F04777BD1193451D84CBCF'
                'double: -1.0',-1.0
                'double: -inf',-Inf
                'double: 0.0',0.0
                'double: 123.45',123.45
                'double: inf',Inf
                'double: nan',NULL
                'integer: -1',-1
                'integer: 0',0
                'integer: 123',123
                'integer: max',9223372036854775807
                'integer: min',-9223372036854775808
                'null',NULL
                'text: ascii apostrophe','['']'
                'text: ascii backslash','[\\]'
                'text: ascii double quote','["]'
                'text: ascii line feed','[
                ]'
                'text: ascii long','Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus.'
                'text: ascii short','Hello'
                'text: ascii slash','[/]'
                'text: ascii tab','[\t]'
                'text: ascii url','https://github.com/groue/GRDB.swift'
                'text: empty',''
                'text: utf8 short','您好🙂'
                
                """)
        }
    }
    
    func test_quote_empty_results() throws {
        try makeDatabaseQueue().write { db in
            do {
                // Columns
                let stream = TestStream()
                try db.dumpSQL("SELECT NULL WHERE NULL", format: .quote(), to: stream)
                XCTAssertEqual(stream.output, "")
            }
            do {
                // No columns
                let stream = TestStream()
                try db.dumpSQL("CREATE TABLE t(a)", format: .quote(), to: stream)
                XCTAssertEqual(stream.output, "")
            }
        }
    }
    
    func test_quote_headers() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Headers on
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .quote(header: true), to: stream)
                XCTAssertEqual(stream.output, """
                    'id','teamId','name'
                    1,'FRA','Antoine Dupond'
                    2,'ENG','Owen Farrell'
                    3,NULL,'Gwendal Roué'
                    
                    """)
            }
            do {
                // Headers on, no result
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player WHERE 0", format: .quote(header: true), to: stream)
                XCTAssertEqual(stream.output, "")
            }
            do {
                // Headers off
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .quote(header: false), to: stream)
                XCTAssertEqual(stream.output, """
                    1,'FRA','Antoine Dupond'
                    2,'ENG','Owen Farrell'
                    3,NULL,'Gwendal Roué'
                    
                    """)
            }
            do {
                // Headers off, no result
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player WHERE 0", format: .quote(header: false), to: stream)
                XCTAssertEqual(stream.output, "")
            }
        }
    }
    
    func test_quote_duplicate_columns() throws {
        try makeDatabaseQueue().read { db in
            let stream = TestStream()
            try db.dumpSQL("SELECT 1 AS name, 'foo' AS name", format: .quote(header: true), to: stream)
            XCTAssertEqual(stream.output, """
                'name','name'
                1,'foo'
                
                """)
        }
    }
    
    func test_quote_multiple_statements() throws {
        try makeDatabaseQueue().write { db in
            let stream = TestStream()
            try db.dumpSQL(
                """
                CREATE TABLE t(a, b);
                INSERT INTO t VALUES (1, 'foo');
                INSERT INTO t VALUES (2, 'bar');
                SELECT * FROM t ORDER BY a;
                SELECT b FROM t ORDER BY b;
                SELECT NULL WHERE NULL;
                """,
                format: .quote(),
                to: stream)
            XCTAssertEqual(stream.output, """
                1,'foo'
                2,'bar'
                'bar'
                'foo'
                
                """)
        }
    }
    
    func test_quote_separator() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default separator
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .quote(header: true), to: stream)
                XCTAssertEqual(stream.output, """
                    'id','teamId','name'
                    1,'FRA','Antoine Dupond'
                    2,'ENG','Owen Farrell'
                    3,NULL,'Gwendal Roué'
                    
                    """)
            }
            do {
                // Custom separator
                let stream = TestStream()
                try db.dumpSQL("SELECT * FROM player ORDER BY id", format: .quote(header: true, separator: "---"), to: stream)
                XCTAssertEqual(stream.output, """
                    'id'---'teamId'---'name'
                    1---'FRA'---'Antoine Dupond'
                    2---'ENG'---'Owen Farrell'
                    3---NULL---'Gwendal Roué'
                    
                    """)
            }
        }
    }
    
    // MARK: - Dump error
    
    func test_dumpError() throws {
        try makeDatabaseQueue().read { db in
            let stream = TestStream()
            do {
                try db.dumpSQL(
                    """
                    SELECT 'Hello';
                    Not sql;
                    """,
                    to: stream)
                XCTFail("Expected error")
            } catch {
                XCTAssertEqual(stream.output, """
                    Hello
                    
                    """)
            }
        }
    }
    
    // MARK: - Request dump
    
    func test_dumpRequest() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default format
                let stream = TestStream()
                try db.dumpRequest(Player.orderByPrimaryKey(), to: stream)
                XCTAssertEqual(stream.output, """
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Custom format
                let stream = TestStream()
                try db.dumpRequest(Player.orderByPrimaryKey(), format: .json(), to: stream)
                XCTAssertEqual(stream.output, """
                    [{"id":1,"teamId":"FRA","name":"Antoine Dupond"},
                    {"id":2,"teamId":"ENG","name":"Owen Farrell"},
                    {"id":3,"teamId":null,"name":"Gwendal Roué"}]
                    
                    """)
            }
        }
    }
    
    func test_dumpRequest_association_to_one() throws {
        try makeRugbyDatabase().read { db in
            let request = Player.orderByPrimaryKey().including(required: Player.team)
            
            do {
                // Default format
                let stream = TestStream()
                try db.dumpRequest(request, to: stream)
                XCTAssertEqual(stream.output, """
                    1|FRA|Antoine Dupond|FRA|XV de France|blue
                    2|ENG|Owen Farrell|ENG|England Rugby|white
                    
                    """)
            }
            do {
                // Custom format
                let stream = TestStream()
                try db.dumpRequest(request, format: .json(), to: stream)
                XCTAssertEqual(stream.output, """
                    [{"id":1,"teamId":"FRA","name":"Antoine Dupond","id":"FRA","name":"XV de France","color":"blue"},
                    {"id":2,"teamId":"ENG","name":"Owen Farrell","id":"ENG","name":"England Rugby","color":"white"}]
                    
                    """)
            }
        }
    }
    
    func test_dumpRequest_association_to_many() throws {
        try makeRugbyDatabase().read { db in
            let request = Team.orderByPrimaryKey().including(all: Team.players.orderByPrimaryKey())
            
            do {
                // Default format
                let stream = TestStream()
                try db.dumpRequest(request, to: stream)
                XCTAssertEqual(stream.output, """
                    ENG|England Rugby|white
                    FRA|XV de France|blue
                    
                    players
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    
                    """)
            }
            do {
                // Custom format
                let stream = TestStream()
                try db.dumpRequest(request, format: .json(), to: stream)
                XCTAssertEqual(stream.output, """
                    [{"id":"ENG","name":"England Rugby","color":"white"},
                    {"id":"FRA","name":"XV de France","color":"blue"}]
                    
                    players
                    [{"id":1,"teamId":"FRA","name":"Antoine Dupond"},
                    {"id":2,"teamId":"ENG","name":"Owen Farrell"}]
                    
                    """)
            }
        }
    }
    
    // MARK: - Table dump
    
    func test_dumpTables_zero() throws {
        try makeRugbyDatabase().read { db in
            let stream = TestStream()
            try db.dumpTables([], to: stream)
            XCTAssertEqual(stream.output, "")
        }
    }
    
    func test_dumpTables_single_table() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default format
                let stream = TestStream()
                try db.dumpTables(["player"], to: stream)
                XCTAssertEqual(stream.output, """
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    """)
            }
            do {
                // Custom format
                let stream = TestStream()
                try db.dumpTables(["player"], format: .json(), to: stream)
                XCTAssertEqual(stream.output, """
                    [{"id":1,"teamId":"FRA","name":"Antoine Dupond"},
                    {"id":2,"teamId":"ENG","name":"Owen Farrell"},
                    {"id":3,"teamId":null,"name":"Gwendal Roué"}]
                    
                    """)
            }
        }
    }
    
    func test_dumpTables_single_view() throws {
        try makeRugbyDatabase().write { db in
            try db.create(view: "playerName", as: Player
                .orderByPrimaryKey()
                .select(Column("name")))
            
            do {
                // Default order: use the view ordering
                do {
                    // Default format
                    let stream = TestStream()
                    try db.dumpTables(["playerName"], to: stream)
                    XCTAssertEqual(stream.output, """
                    Antoine Dupond
                    Owen Farrell
                    Gwendal Roué
                    
                    """)
                }
                do {
                    // Custom format
                    let stream = TestStream()
                    try db.dumpTables(["playerName"], format: .json(), to: stream)
                    XCTAssertEqual(stream.output, """
                    [{"name":"Antoine Dupond"},
                    {"name":"Owen Farrell"},
                    {"name":"Gwendal Roué"}]
                    
                    """)
                }
            }
            
            do {
                // Stable order
                do {
                    // Default format
                    let stream = TestStream()
                    try db.dumpTables(["playerName"], stableOrder: true, to: stream)
                    XCTAssertEqual(stream.output, """
                    Antoine Dupond
                    Gwendal Roué
                    Owen Farrell
                    
                    """)
                }
                do {
                    // Custom format
                    let stream = TestStream()
                    try db.dumpTables(["playerName"], format: .json(), stableOrder: true, to: stream)
                    XCTAssertEqual(stream.output, """
                    [{"name":"Antoine Dupond"},
                    {"name":"Gwendal Roué"},
                    {"name":"Owen Farrell"}]
                    
                    """)
                }
            }
        }
    }
    
    func test_dumpTables_multiple() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default format
                let stream = TestStream()
                try db.dumpTables(["player", "team"], to: stream)
                XCTAssertEqual(stream.output, """
                    player
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    team
                    ENG|England Rugby|white
                    FRA|XV de France|blue
                    
                    """)
            }
            do {
                // Custom format
                let stream = TestStream()
                try db.dumpTables(["team", "player"], format: .json(), to: stream)
                XCTAssertEqual(stream.output, """
                    team
                    [{"id":"ENG","name":"England Rugby","color":"white"},
                    {"id":"FRA","name":"XV de France","color":"blue"}]
                    
                    player
                    [{"id":1,"teamId":"FRA","name":"Antoine Dupond"},
                    {"id":2,"teamId":"ENG","name":"Owen Farrell"},
                    {"id":3,"teamId":null,"name":"Gwendal Roué"}]
                    
                    """)
            }
        }
    }
    
    // MARK: - Database content dump
    
    func test_dumpContent() throws {
        try makeRugbyDatabase().read { db in
            do {
                // Default format
                let stream = TestStream()
                try db.dumpContent(to: stream)
                XCTAssertEqual(stream.output, """
                    sqlite_master
                    CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "teamId" TEXT REFERENCES "team"("id"), "name" TEXT NOT NULL);
                    CREATE INDEX "player_on_teamId" ON "player"("teamId");
                    CREATE TABLE "team" ("id" TEXT PRIMARY KEY NOT NULL, "name" TEXT NOT NULL, "color" TEXT NOT NULL);
                    
                    player
                    1|FRA|Antoine Dupond
                    2|ENG|Owen Farrell
                    3||Gwendal Roué
                    
                    team
                    ENG|England Rugby|white
                    FRA|XV de France|blue
                    
                    """)
            }
            do {
                // Custom format
                let stream = TestStream()
                try db.dumpContent(format: .json(), to: stream)
                XCTAssertEqual(stream.output, """
                    sqlite_master
                    CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "teamId" TEXT REFERENCES "team"("id"), "name" TEXT NOT NULL);
                    CREATE INDEX "player_on_teamId" ON "player"("teamId");
                    CREATE TABLE "team" ("id" TEXT PRIMARY KEY NOT NULL, "name" TEXT NOT NULL, "color" TEXT NOT NULL);
                    
                    player
                    [{"id":1,"teamId":"FRA","name":"Antoine Dupond"},
                    {"id":2,"teamId":"ENG","name":"Owen Farrell"},
                    {"id":3,"teamId":null,"name":"Gwendal Roué"}]
                    
                    team
                    [{"id":"ENG","name":"England Rugby","color":"white"},
                    {"id":"FRA","name":"XV de France","color":"blue"}]
                    
                    """)
            }
        }
    }
    
    func test_dumpContent_empty_database() throws {
        try makeDatabaseQueue().read { db in
            let stream = TestStream()
            try db.dumpContent(to: stream)
            XCTAssertEqual(stream.output, """
                sqlite_master
                
                """)
        }
    }
    
    func test_dumpContent_empty_tables() throws {
        try makeDatabaseQueue().write { db in
            try db.execute(literal: """
                CREATE TABLE blue(name);
                CREATE TABLE red(name);
                CREATE TABLE yellow(name);
                INSERT INTO red VALUES ('vermillon')
                """)
            let stream = TestStream()
            try db.dumpContent(to: stream)
            XCTAssertEqual(stream.output, """
                sqlite_master
                CREATE TABLE blue(name);
                CREATE TABLE red(name);
                CREATE TABLE yellow(name);
                
                blue
                
                red
                vermillon
                
                yellow
                
                """)
        }
    }
    
    func test_dumpContent_sqlite_master_ordering() throws {
        try makeDatabaseQueue().write { db in
            try db.execute(literal: """
                CREATE TABLE blue(name);
                CREATE TABLE RED(name);
                CREATE TABLE yellow(name);
                CREATE INDEX index_blue1 ON blue(name);
                CREATE INDEX INDEX_blue2 ON blue(name);
                CREATE INDEX indexRed1 ON RED(name);
                CREATE INDEX INDEXRed2 ON RED(name);
                CREATE VIEW colors1 AS SELECT name FROM blue;
                CREATE VIEW COLORS2 AS SELECT name FROM blue UNION SELECT name FROM yellow;
                CREATE TRIGGER update_blue UPDATE OF name ON blue
                  BEGIN
                    DELETE FROM RED;
                  END;
                CREATE TRIGGER update_RED UPDATE OF name ON RED
                  BEGIN
                    DELETE FROM yellow;
                  END;
                """)
            let stream = TestStream()
            try db.dumpContent(to: stream)
            XCTAssertEqual(stream.output, """
                sqlite_master
                CREATE TABLE blue(name);
                CREATE INDEX index_blue1 ON blue(name);
                CREATE INDEX INDEX_blue2 ON blue(name);
                CREATE TRIGGER update_blue UPDATE OF name ON blue
                  BEGIN
                    DELETE FROM RED;
                  END;
                CREATE VIEW colors1 AS SELECT name FROM blue;
                CREATE VIEW COLORS2 AS SELECT name FROM blue UNION SELECT name FROM yellow;
                CREATE TABLE RED(name);
                CREATE INDEX indexRed1 ON RED(name);
                CREATE INDEX INDEXRed2 ON RED(name);
                CREATE TRIGGER update_RED UPDATE OF name ON RED
                  BEGIN
                    DELETE FROM yellow;
                  END;
                CREATE TABLE yellow(name);
                
                blue
                
                RED
                
                yellow
                
                """)
        }
    }
    
    func test_dumpContent_ignores_shadow_tables() throws {
        guard sqlite3_libversion_number() >= 3037000 else {
            throw XCTSkip("Can't detect shadow tables")
        }
        
        try makeDatabaseQueue().write { db in
            try db.create(table: "document") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("body")
            }
            
            try db.execute(sql: "INSERT INTO document VALUES (1, 'Hello world!')")
            
            try db.create(virtualTable: "document_ft", using: FTS4()) { t in
                t.synchronize(withTable: "document")
                t.column("body")
            }
            
            let stream = TestStream()
            try db.dumpContent(to: stream)
            print(stream.output)
            XCTAssertEqual(stream.output, """
                sqlite_master
                CREATE TABLE "document" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "body");
                CREATE TRIGGER "__document_ft_ai" AFTER INSERT ON "document" BEGIN
                    INSERT INTO "document_ft"("docid", "body") VALUES(new."id", new."body");
                END;
                CREATE TRIGGER "__document_ft_au" AFTER UPDATE ON "document" BEGIN
                    INSERT INTO "document_ft"("docid", "body") VALUES(new."id", new."body");
                END;
                CREATE TRIGGER "__document_ft_bd" BEFORE DELETE ON "document" BEGIN
                    DELETE FROM "document_ft" WHERE docid=old."id";
                END;
                CREATE TRIGGER "__document_ft_bu" BEFORE UPDATE ON "document" BEGIN
                    DELETE FROM "document_ft" WHERE docid=old."id";
                END;
                CREATE VIRTUAL TABLE "document_ft" USING fts4(body, content="document");
                
                document
                1|Hello world!
                
                document_ft
                Hello world!
                
                """)
        }
    }
    
    func test_dumpContent_ignores_GRDB_internal_tables() throws {
        let dbQueue = try makeDatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        try migrator.migrate(dbQueue)
        
        try dbQueue.read { db in
            let stream = TestStream()
            try db.dumpContent(to: stream)
            print(stream.output)
            XCTAssertEqual(stream.output, """
                sqlite_master
                CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT);

                player
                
                """)
        }
    }
    
    // MARK: - Support Databases
    
    private func makeValuesDatabase() throws -> DatabaseQueue {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(literal: """
                CREATE TABLE value(name, value);
                
                INSERT INTO value VALUES ('blob: ascii long', CAST('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus.' AS BLOB));
                INSERT INTO value VALUES ('blob: ascii short', CAST('Hello' AS BLOB));
                INSERT INTO value VALUES ('blob: ascii tab', CAST('['||char(9)||']' AS BLOB));
                INSERT INTO value VALUES ('blob: ascii line feed', CAST('['||char(10)||']' AS BLOB));
                INSERT INTO value VALUES ('blob: ascii apostrophe', CAST('['']' AS BLOB));
                INSERT INTO value VALUES ('blob: ascii double quote', CAST('["]' AS BLOB));
                INSERT INTO value VALUES ('blob: binary short', X'80');
                INSERT INTO value VALUES ('blob: empty', x'');
                INSERT INTO value VALUES ('blob: utf8 short', CAST('您好🙂' AS BLOB));
                INSERT INTO value VALUES ('blob: uuid', x'69BF8A9CD9F04777BD1193451D84CBCF');
                
                INSERT INTO value VALUES ('double: -1.0', -1.0);
                INSERT INTO value VALUES ('double: -inf', \(-1.0 / 0));
                INSERT INTO value VALUES ('double: 0.0', 0.0);
                INSERT INTO value VALUES ('double: 123.45', 123.45);
                INSERT INTO value VALUES ('double: inf', \(1.0 / 0));
                INSERT INTO value VALUES ('double: nan', \(0.0 / 0));
                
                INSERT INTO value VALUES ('integer: 0', 0);
                INSERT INTO value VALUES ('integer: -1', -1);
                INSERT INTO value VALUES ('integer: 123', 123);
                INSERT INTO value VALUES ('integer: max', 9223372036854775807);
                INSERT INTO value VALUES ('integer: min', -9223372036854775808);
                
                INSERT INTO value VALUES ('null', NULL);
                
                INSERT INTO value VALUES ('text: empty', '');
                INSERT INTO value VALUES ('text: ascii apostrophe', '['']');
                INSERT INTO value VALUES ('text: ascii backslash', '[\\]');
                INSERT INTO value VALUES ('text: ascii double quote', '["]');
                INSERT INTO value VALUES ('text: ascii long', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique tempor condimentum. Pellentesque pharetra lacus non ante sollicitudin auctor. Vestibulum sit amet mauris vitae urna non luctus.');
                INSERT INTO value VALUES ('text: ascii line feed', '['||char(10)||']');
                INSERT INTO value VALUES ('text: ascii short', 'Hello');
                INSERT INTO value VALUES ('text: ascii slash', '[/]');
                INSERT INTO value VALUES ('text: ascii tab', '['||char(9)||']');
                INSERT INTO value VALUES ('text: ascii url', 'https://github.com/groue/GRDB.swift');
                INSERT INTO value VALUES ('text: utf8 short', '您好🙂');
                """)
        }
        return dbQueue
    }
    
    private func makeRugbyDatabase() throws -> DatabaseQueue {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "team") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("color", .text).notNull()
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("team")
                t.column("name", .text).notNull()
            }
            
            let england = Team(id: "ENG", name: "England Rugby", color: "white")
            let france = Team(id: "FRA", name: "XV de France", color: "blue")
            
            try england.insert(db)
            try france.insert(db)
            
            _ = try Player(name: "Antoine Dupond", teamId: france.id).inserted(db)
            _ = try Player(name: "Owen Farrell", teamId: england.id).inserted(db)
            _ = try Player(name: "Gwendal Roué", teamId: nil).inserted(db)
        }
        return dbQueue
    }
}
