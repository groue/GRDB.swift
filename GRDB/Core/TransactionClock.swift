import Foundation

/// A type that provides the moment of a transaction.
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// ## Topics
///
/// ### Built-in Clocks
///
/// - ``DefaultTransactionClock``
/// - ``CustomTransactionClock``
public protocol TransactionClock {
    /// Returns the date of the current transaction.
    ///
    /// This function is called whenever a transaction starts - precisely
    /// speaking, whenever the database connection leaves the auto-commit mode.
    ///
    /// It is also called when the ``Database/transactionDate`` property is
    /// called, and the database connection is not in a transaction.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/c3ref/get_autocommit.html>
    func now(_ db: Database) throws -> Date
}

extension TransactionClock where Self == DefaultTransactionClock {
    /// Returns the default clock.
    public static var `default`: Self { DefaultTransactionClock() }
}

extension TransactionClock where Self == CustomTransactionClock {
    /// Returns a custom clock.
    ///
    /// The provided closure is called whenever a transaction starts - precisely
    /// speaking, whenever the database connection leaves the auto-commit mode.
    ///
    /// It is also called when the ``Database/transactionDate`` property is
    /// called, and the database connection is not in a transaction.
    public static func custom(_ now: @escaping (Database) throws -> Date) -> Self {
        CustomTransactionClock(now)
    }
}

/// The default transaction clock.
public struct DefaultTransactionClock: TransactionClock {
    /// Returns the start date of the current transaction.
    public func now(_ db: Database) throws -> Date {
        // An opportunity to fetch transaction time from the database when
        // SQLite supports the feature.
        Date()
    }
}

/// A custom transaction clock.
public struct CustomTransactionClock: TransactionClock {
    let _now: (Database) throws -> Date
    
    public init(_ now: @escaping (Database) throws -> Date) {
        self._now = now
    }
    
    public func now(_ db: Database) throws -> Date {
        try _now(db)
    }
}
