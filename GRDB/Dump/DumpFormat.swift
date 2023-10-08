/// A type that prints database rows.
///
/// Types that conform to `DumpFormat` feed the printing methods such as
/// ``DatabaseReader/dumpContent(format:to:)`` and
/// ``Database/dumpSQL(_:format:to:)``.
///
/// Most built-in formats are inspired from the
/// [output formats of the SQLite command line tool](https://sqlite.org/cli.html#changing_output_formats).
///
/// ## Topics
///
/// ### Built-in Formats
///
/// - ``debug(header:separator:nullValue:)``
/// - ``json(encoder:)``
/// - ``line(nullValue:)``
/// - ``list(header:separator:nullValue:)``
/// - ``quote(header:separator:)``
///
/// ### Supporting Types
///
/// - ``DebugDumpFormat``
/// - ``JSONDumpFormat``
/// - ``LineDumpFormat``
/// - ``ListDumpFormat``
/// - ``QuoteDumpFormat``
/// - ``DumpStream``
///
/// ### Implementing a custom format
///
/// [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// - ``writeRow(_:statement:to:)``
/// - ``finalize(_:statement:to:)``
public protocol DumpFormat {
    /// Writes a row from the given statement.
    ///
    /// - Parameters:
    ///   - db: A connection to the database
    ///   - statement: The iterated statement
    ///   - stream: A stream for text output.
    mutating func writeRow(
        _ db: Database,
        statement: Statement,
        to stream: inout DumpStream) throws
    
    /// All rows from the statement have been printed.
    ///
    /// - Parameters:
    ///   - db: A connection to the database
    ///   - statement: The statement that was iterated.
    ///   - stream: A stream for text output.
    mutating func finalize(
        _ db: Database,
        statement: Statement,
        to stream: inout DumpStream)
}

/// A TextOutputStream that prints to standard output
struct StandardOutputStream: TextOutputStream {
    func write(_ string: String) {
        print(string, terminator: "")
    }
}

/// A text output stream suited for printing database content.
///
/// [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
public struct DumpStream {
    var base: any TextOutputStream
    var needsMarginLine = false
    
    init(_ base: (any TextOutputStream)?) {
        self.base = base ?? StandardOutputStream()
    }
    
    /// Will write `"\n"` before the next non-empty string.
    public mutating func margin() {
        needsMarginLine = true
    }
}

extension DumpStream: TextOutputStream {
    public mutating func write(_ string: String) {
        if needsMarginLine && !string.isEmpty {
            needsMarginLine = false
            if string.first != "\n" {
                base.write("\n")
            }
        }
        base.write(string)
    }
}

extension TextOutputStream {
    mutating func writeln(_ string: String) {
        write(string)
        write("\n")
    }
}

extension String {
    func leftPadding(toLength newLength: Int, withPad padString: String) -> String {
        precondition(padString.count == 1)
        if count < newLength {
            return String(repeating: padString, count: newLength - count) + self
        } else {
            let startIndex = index(startIndex, offsetBy: count - newLength)
            return String(self[startIndex...])
        }
    }
}
