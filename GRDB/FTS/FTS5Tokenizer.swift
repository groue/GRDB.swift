#if SQLITE_ENABLE_FTS5
    /// An FTS5 tokenizer, suitable for FTS5 table definitions:
    ///
    ///     db.create(virtualTable: "books", using: FTS5()) { t in
    ///         t.tokenizer = FTS5Tokenizer.unicode61()
    ///     }
    ///
    /// See https://www.sqlite.org/fts5.html#tokenizers
    public struct FTS5Tokenizer {
        let components: [String]
        
        private init(components: [String]) {
            assert(!components.isEmpty)
            self.components = components
        }
        
        /// Creates an FTS5 tokenizer.
        ///
        /// Unless you use a custom tokenizer, you don't need this constructor:
        ///
        /// Use FTS5Tokenizer.ascii(), FTS5Tokenizer.porter(), or
        /// FTS5Tokenizer.unicode61() instead.
        public init(_ name: String, arguments: [String] = []) {
            self.init(components: [name] + arguments)
        }
        
        /// The "ascii" tokenizer
        ///
        ///     db.create(virtualTable: "books", using: FTS5()) { t in
        ///         t.tokenizer = .ascii()
        ///     }
        ///
        /// - parameters:
        ///     - separators: Unless empty (the default), SQLite will consider
        ///       these characters as token separators.
        ///
        /// See https://www.sqlite.org/fts5.html#ascii_tokenizer
        public static func ascii(separators: Set<Character> = []) -> FTS5Tokenizer {
            if separators.isEmpty {
                return FTS5Tokenizer("ascii")
            } else {
                return FTS5Tokenizer("ascii", arguments: ["separators", separators.map { String($0) }.joined(separator: "").sqlExpression.sql])
            }
        }
        
        /// The "porter" tokenizer
        ///
        ///     db.create(virtualTable: "books", using: FTS5()) { t in
        ///         t.tokenizer = .porter()
        ///     }
        ///
        /// - parameters:
        ///     - base: An eventual wrapping tokenizer which replaces the
        //        default unicode61() base tokenizer.
        ///
        /// See https://www.sqlite.org/fts5.html#porter_tokenizer
        public static func porter(wrapping base: FTS5Tokenizer? = nil) -> FTS5Tokenizer {
            if let base = base {
                return FTS5Tokenizer("porter", arguments: base.components)
            } else {
                return FTS5Tokenizer("porter")
            }
        }
        
        /// An "unicode61" tokenizer
        ///
        ///     db.create(virtualTable: "books", using: FTS5()) { t in
        ///         t.tokenizer = .unicode61()
        ///     }
        ///
        /// - parameters:
        ///     - removeDiacritics: If true (the default), then SQLite will
        ///       strip diacritics from latin characters.
        ///     - separators: Unless empty (the default), SQLite will consider
        ///       these characters as token separators.
        ///     - tokenCharacters: Unless empty (the default), SQLite will
        ///       consider these characters as token characters.
        ///
        /// See https://www.sqlite.org/fts5.html#unicode61_tokenizer
        public static func unicode61(removeDiacritics: Bool = true, separators: Set<Character> = [], tokenCharacters: Set<Character> = []) -> FTS5Tokenizer {
            var arguments: [String] = []
            if !removeDiacritics {
                arguments.append(contentsOf: ["remove_diacritics", "0"])
            }
            if !separators.isEmpty {
                // TODO: test "=" and "\"", "(" and ")" as separators, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
                arguments.append(contentsOf: ["separators", separators.sorted().map { String($0) }.joined(separator: "").sqlExpression.sql])
            }
            if !tokenCharacters.isEmpty {
                // TODO: test "=" and "\"", "(" and ")" as tokenCharacters, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
                arguments.append(contentsOf: ["tokenchars", tokenCharacters.sorted().map { String($0) }.joined(separator: "").sqlExpression.sql])
            }
            return FTS5Tokenizer("unicode61", arguments: arguments)
        }
    }
    
    public protocol FTS5TokenizerDefinition : class {
        init(db: Database, arguments: [String]) throws
    }
    
    extension Database {
        
        public struct FTS5TokenizerInfo {
            let tokenizer: fts5_tokenizer
            let userData: UnsafeRawPointer?
        }
        
        public func fts5api() -> UnsafePointer<fts5_api>? {
            return Data
                .fetchOne(self, "SELECT fts5()")
                .flatMap { data in
                    guard data.count == MemoryLayout<UnsafePointer<fts5_api>>.size else { return nil }
                    return data.withUnsafeBytes { (api: UnsafePointer<UnsafePointer<fts5_api>>) in api.pointee }
            }
        }
        
        public func fts5tokenizer(name: String) -> FTS5TokenizerInfo? {
            return fts5api().flatMap { api in
                let tokenizerPointer: UnsafeMutablePointer<fts5_tokenizer> = .allocate(capacity: 1)
                defer { tokenizerPointer.deallocate(capacity: 1) }
                
                let userDataPointer: UnsafeMutablePointer<UnsafeMutableRawPointer?> = .allocate(capacity: 1)
                defer { userDataPointer.deallocate(capacity: 1) }
                
                let code = api.pointee.xFindTokenizer!(
                    UnsafeMutablePointer(mutating: api),
                    name,
                    userDataPointer,
                    tokenizerPointer)
                
                guard code == SQLITE_OK else { return nil }
                
                return FTS5TokenizerInfo(tokenizer: tokenizerPointer.pointee, userData: userDataPointer.pointee.flatMap { UnsafeRawPointer($0) })
            }
        }
        
        private class FTS5TokenizerCreationContext {
            let db: Database
            let constructor: (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> Int32
            
            init(db: Database, constructor: @escaping (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> Int32) {
                self.db = db
                self.constructor = constructor
            }
        }
        
        public func add<Tokenizer: FTS5TokenizerDefinition>(tokenizer: Tokenizer.Type, name: String) throws {
            guard let api = fts5api() else {
                throw DatabaseError(code: SQLITE_MISUSE, message: "FTS5 API not found")
            }
            let context = FTS5TokenizerCreationContext(db: self, constructor: { (db, arguments, tokenizerHandle) in
                guard let tokenizerHandle = tokenizerHandle else { return SQLITE_ERROR }
                do {
                    let tokenizer = try Tokenizer(db: db, arguments: arguments)
                    let tokenizerPointer = OpaquePointer(Unmanaged.passRetained(tokenizer).toOpaque())
                    tokenizerHandle.pointee = tokenizerPointer
                    return SQLITE_OK
                } catch let error as DatabaseError {
                    return error.code
                } catch {
                    return SQLITE_ERROR
                }
            })
            var fts5tokenizer = fts5_tokenizer(
                xCreate: { (contextPointer, azArg, nArg, tokenizerHandle) -> Int32 in
                    guard let contextPointer = contextPointer else { return SQLITE_ERROR }
                    let context = Unmanaged<FTS5TokenizerCreationContext>.fromOpaque(contextPointer).takeUnretainedValue()
                    var arguments: [String] = []
                    if let azArg = azArg {
                        for i in 0..<Int(nArg) {
                            if let cstr = azArg[i] {
                                arguments.append(String(cString: cstr))
                            }
                        }
                    }
                    return context.constructor(context.db, arguments, tokenizerHandle)
                },
                xDelete: { tokenizerPointer in
                    if let tokenizerPointer = tokenizerPointer {
                        Unmanaged<AnyObject>.fromOpaque(UnsafeMutableRawPointer(tokenizerPointer)).release()
                    }
                },
                xTokenize: { (a, b, c, d, e, f) -> Int32 in
                    return 0
            })
            let contextPointer = Unmanaged.passRetained(context).toOpaque()
            let code = withUnsafeMutablePointer(to: &fts5tokenizer) { fts5tokenizerPointer in
                api.pointee.xCreateTokenizer(
                    UnsafeMutablePointer(mutating: api),
                    name,
                    contextPointer,
                    fts5tokenizerPointer,
                    { contextPointer in
                        if let contextPointer = contextPointer {
                            Unmanaged<FTS5TokenizerCreationContext>.fromOpaque(contextPointer).release()
                        }
                    }
                )
            }
            guard code == SQLITE_OK else {
                throw DatabaseError(code: code, message: lastErrorMessage)
            }
        }
    }
#endif
