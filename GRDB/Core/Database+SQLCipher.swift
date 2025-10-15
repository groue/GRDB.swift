#if SQLITE_HAS_CODEC
import SQLCipher

extension Database {
    
    /// Granularitly of SQLCipher log outputs
    /// Each log level is more verbose than the last
    ///
    /// See https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_log_level
    public enum CipherLogLevel: String {
        case none
        case error
        case warn
        case info
        case debug
        case trace
    }
    
    /// - Returns: the SQLCipher version
    ///
    /// See https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_version
    public var cipherVersion: String {
        get throws { try String.fetchOne(self, sql: "PRAGMA cipher_version")! }
    }
    
    /// - Returns: the SQLCipher fips status: 1 for fips mode, 0 for non-fips mode
    /// The FIPS status will not be initialized until the database connection has been keyed
    ///
    /// See https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_fips_status
    public var cipherFipsStatus: String? {
        get throws { try String.fetchOne(self, sql: "PRAGMA cipher_fips_status") }
    }
    
    /// - Returns: The compiled crypto provider.
    /// The database must be keyed before requesting the name of the crypto provider.
    ///
    /// See https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_provider
    public var cipherProvider: String? {
        get throws { try String.fetchOne(self, sql: "PRAGMA cipher_provider") }
    }
    
    /// - Returns: the version number provided from the compiled crypto provider.
    /// This value, if known, is available only after the database has been keyed.
    ///
    /// See https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_provider_version
    public var cipherProviderVersion: String? {
        get throws { try String.fetchOne(self, sql: "PRAGMA cipher_provider_version") }
    }
    
    /// Sets the passphrase used to crypt and decrypt an SQLCipher database.
    ///
    /// Call this method from `Configuration.prepareDatabase`,
    /// as in the example below:
    ///
    ///     var config = Configuration()
    ///     config.prepareDatabase { db in
    ///         try db.usePassphrase("secret")
    ///     }
    public func usePassphrase(_ passphrase: String) throws {
        guard var data = passphrase.data(using: .utf8) else {
            throw DatabaseError(message: "invalid passphrase")
        }
        defer {
            data.resetBytes(in: 0..<data.count)
        }
        try usePassphrase(data)
    }
    
    /// Sets the passphrase used to crypt and decrypt an SQLCipher database.
    ///
    /// Call this method from `Configuration.prepareDatabase`,
    /// as in the example below:
    ///
    ///     var config = Configuration()
    ///     config.prepareDatabase { db in
    ///         try db.usePassphrase(passphraseData)
    ///     }
    public func usePassphrase(_ passphrase: Data) throws {
        let code = passphrase.withUnsafeBytes {
            sqlite3_key(sqliteConnection, $0.baseAddress, CInt($0.count))
        }
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: String(cString: sqlite3_errmsg(sqliteConnection)))
        }
    }
    
    /// Changes the passphrase used by an SQLCipher encrypted database.
    public func changePassphrase(_ passphrase: String) throws {
        guard var data = passphrase.data(using: .utf8) else {
            throw DatabaseError(message: "invalid passphrase")
        }
        defer {
            data.resetBytes(in: 0..<data.count)
        }
        try changePassphrase(data)
    }
    
    /// Changes the passphrase used by an SQLCipher encrypted database.
    public func changePassphrase(_ passphrase: Data) throws {
        // FIXME: sqlite3_rekey is discouraged.
        //
        // https://github.com/ccgus/fmdb/issues/547#issuecomment-259219320
        //
        // > We (Zetetic) have been discouraging the use of sqlite3_rekey in
        // > favor of attaching a new database with the desired encryption
        // > options and using sqlcipher_export() to migrate the contents and
        // > schema of the original db into the new one:
        // > https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/
        let code = passphrase.withUnsafeBytes {
            sqlite3_rekey(sqliteConnection, $0.baseAddress, CInt($0.count))
        }
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code, message: lastErrorMessage)
        }
    }
    
    /// When using Commercial or Enterprise SQLCipher packages you must call
    /// `PRAGMA cipher_license` with a valid license code prior to executing
    /// cryptographic operations on an encrypted database.
    /// Failure to provide a license code, or use of an expired trial code,
    /// will result in an `SQLITE_AUTH (23)` error code reported from the SQLite API
    /// License Codes will activate SQLCipher Commercial or Enterprise packages
    /// from Zetetic: https://www.zetetic.net/sqlcipher/buy/
    /// 15-day free trials are available by request: https://www.zetetic.net/sqlcipher/trial/
    ///
    /// Call this method from `Configuration.prepareDatabase`,
    /// as in the example below:
    ///
    ///     var config = Configuration()
    ///     config.prepareDatabase { db in
    ///         try db.applyLicense(license)
    ///     }
    ///
    /// See https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_license
    /// - Parameter license: base64 SQLCipher license code to activate SQLCipher commercial
    public func applyLicense(_ license: String) throws {
        try execute(sql: "PRAGMA cipher_license = '\(license)'")
    }
    
    /// Instructs SQLCipher to log internal debugging and operational information
    /// to the sepecified log target (device) using `os_log`
    /// The supplied logLevel will determine the granularity of the logs output
    /// Available logLevel options are: NONE, ERROR, WARN, INFO, DEBUG, TRACE
    /// Note that each level is more verbose than the last,
    /// and particularly with DEBUG and TRACE the logging system will generate
    /// a significant log volume
    ///
    /// See https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_log
    /// - Parameter logLevel: CipherLogLevel The granularity to use for the logging system - defaults to `DEBUG`
    public func enableCipherLogging(logLevel: CipherLogLevel = .debug) throws {
        try execute(sql: "PRAGMA cipher_log = device")
        try execute(sql: "PRAGMA cipher_log_level = \(logLevel.rawValue.uppercased())")
    }
    
    /// Instructs SQLCipher to disable logging internal debugging and operational information
    ///
    /// See https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_log
    public func disableCipherLogging() throws {
        try execute(sql: "PRAGMA cipher_log_level = \(CipherLogLevel.none.rawValue.uppercased())")
    }
    
    internal func validateSQLCipher() throws {
        // https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
        //
        // > In order to avoid situations where SQLite might be used
        // > improperly at runtime, we strongly recommend that
        // > applications institute a runtime test to ensure that the
        // > application is actually using SQLCipher on the active
        // > connection.
        if try String.fetchOne(self, sql: "PRAGMA cipher_version") == nil {
            throw DatabaseError(resultCode: .SQLITE_MISUSE, message: """
                GRDB is not linked against SQLCipher. \
                Check https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
                """)
        }
    }
    
    internal func dropAllDatabaseObjects() throws {
        // SQLCipher does not support the backup API:
        // https://discuss.zetetic.net/t/using-the-sqlite-online-backup-api/2631
        // So we'll drop all database objects one after the other.
        
        // Prevent foreign keys from messing with drop table statements
        let foreignKeysEnabled = try Bool.fetchOne(self, sql: "PRAGMA foreign_keys")!
        if foreignKeysEnabled {
            try execute(sql: "PRAGMA foreign_keys = OFF")
        }
        
        try throwingFirstError(
            execute: {
                // Remove all database objects, one after the other
                try inTransaction {
                    let sql = "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'"
                    while let row = try Row.fetchOne(self, sql: sql) {
                        let type: String = row["type"]
                        let name: String = row["name"]
                        try execute(sql: "DROP \(type) \(name.quotedDatabaseIdentifier)")
                    }
                    return .commit
                }
            },
            finally: {
                // Restore foreign keys if needed
                if foreignKeysEnabled {
                    try execute(sql: "PRAGMA foreign_keys = ON")
                }
            })
    }
}

#endif
