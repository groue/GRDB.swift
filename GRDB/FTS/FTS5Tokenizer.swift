#if SQLITE_ENABLE_FTS5
    public typealias FTS5TokenCallback = @convention(c) (_ context: UnsafeMutableRawPointer?, _ flags: Int32, _ pToken: UnsafePointer<Int8>?, _ nToken: Int32, _ iStart: Int32, _ iEnd: Int32) -> Int32
    
    public struct FTS5TokenizeFlags : OptionSet {
        public let rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        /// FTS5_TOKENIZE_QUERY
        public static let query = FTS5TokenizeFlags(rawValue: FTS5_TOKENIZE_QUERY)
        
        /// FTS5_TOKENIZE_PREFIX
        public static let prefix = FTS5TokenizeFlags(rawValue: FTS5_TOKENIZE_PREFIX)
        
        /// FTS5_TOKENIZE_DOCUMENT
        public static let document = FTS5TokenizeFlags(rawValue: FTS5_TOKENIZE_DOCUMENT)
        
        /// FTS5_TOKENIZE_AUX
        public static let aux = FTS5TokenizeFlags(rawValue: FTS5_TOKENIZE_AUX)
    }
    
    public protocol FTS5Tokenizer : class {
        func tokenize(_ context: UnsafeMutableRawPointer?, _ flags: FTS5TokenizeFlags, _ pText: UnsafePointer<Int8>?, _ nText: Int32, _ xToken: FTS5TokenCallback?) -> Int32
    }
    
    private class TokenizeContext {
        var tokens: [String] = []
    }
    
    extension Database {
        private final class FTS5RegisteredTokenizer : FTS5Tokenizer {
            let xTokenizer: fts5_tokenizer
            let tokenizerPointer: OpaquePointer
            
            init(xTokenizer: fts5_tokenizer, contextPointer: UnsafeMutableRawPointer?, arguments: [String]) throws {
                guard let xCreate = xTokenizer.xCreate else {
                    throw DatabaseError(code: SQLITE_ERROR, message: "nil fts5_tokenizer.xCreate")
                }
                
                self.xTokenizer = xTokenizer
                
                var tokenizerPointer: OpaquePointer? = nil
                let code: Int32
                if let argument = arguments.first {
                    // turn [String] into ContiguousArray<UnsafePointer<Int8>>
                    func f<Result>(_ array: inout ContiguousArray<UnsafePointer<Int8>>, _ car: String, _ cdr: [String], _ body: (ContiguousArray<UnsafePointer<Int8>>) -> Result) -> Result {
                        return car.withCString { cString in
                            if let car = cdr.first {
                                array.append(cString)
                                return f(&array, car, Array(cdr.suffix(from: 1)), body)
                            } else {
                                return body(array)
                            }
                        }
                    }
                    var cStrings = ContiguousArray<UnsafePointer<Int8>>()
                    code = f(&cStrings, argument, Array(arguments.suffix(from: 1))) { cStrings in
                        cStrings.withUnsafeBufferPointer { azArg in
                            xCreate(contextPointer, UnsafeMutablePointer(OpaquePointer(azArg.baseAddress!)), Int32(cStrings.count), &tokenizerPointer)
                        }
                    }
                } else {
                    code = xCreate(contextPointer, nil, 0, &tokenizerPointer)
                }
                
                guard code == SQLITE_OK else {
                    throw DatabaseError(code: code, message: "failed fts5_tokenizer.xCreate")
                }
                
                if let tokenizerPointer = tokenizerPointer {
                    self.tokenizerPointer = tokenizerPointer
                } else {
                    throw DatabaseError(code: code, message: "nil tokenizer")
                }
            }
            
            deinit {
                if let delete = xTokenizer.xDelete {
                    delete(tokenizerPointer)
                }
            }
            
            func tokenize(_ context: UnsafeMutableRawPointer?, _ flags: FTS5TokenizeFlags, _ pText: UnsafePointer<Int8>?, _ nText: Int32, _ xToken: FTS5TokenCallback?) -> Int32 {
                guard let xTokenize = xTokenizer.xTokenize else {
                    return SQLITE_ERROR
                }
                return xTokenize(tokenizerPointer, context, flags.rawValue, pText, nText, xToken)
            }
        }
        
        public func makeTokenizer(_ tokenizer: FTS5TokenizerRequest) throws -> FTS5Tokenizer {
            guard let api = FTS5.api(self) else {
                throw DatabaseError(code: SQLITE_MISUSE, message: "FTS5 API not found")
            }
            
            let xTokenizerPointer: UnsafeMutablePointer<fts5_tokenizer> = .allocate(capacity: 1)
            defer { xTokenizerPointer.deallocate(capacity: 1) }
            
            let contextHandle: UnsafeMutablePointer<UnsafeMutableRawPointer?> = .allocate(capacity: 1)
            defer { contextHandle.deallocate(capacity: 1) }
            
            let code = api.pointee.xFindTokenizer!(
                UnsafeMutablePointer(mutating: api),
                tokenizer.name,
                contextHandle,
                xTokenizerPointer)
            
            guard code == SQLITE_OK else {
                throw DatabaseError(code: code)
            }
            
            let contextPointer = contextHandle.pointee
            return try FTS5RegisteredTokenizer(xTokenizer: xTokenizerPointer.pointee, contextPointer: contextPointer, arguments: tokenizer.arguments)
        }
        
        /// Returns an array of tokens found in the string argument.
        ///
        ///     try db.tokenize(string: "foo bar", with: .ascii(), flags: .document) // ["foo", "bar"]
        ///
        /// - parameter string: The string to tokenize
        /// - parameter flags: Tokenization flags
        ///     - .document: Tokenize like a document being inserted into an FTS table.
        ///     - .query: Tokenize like the search pattern of the MATCH operator.
        /// - parameter tokenizer: A FTS5TokenizerRequest such as .ascii()
        public func tokenize(string: String, with tokenizer: FTS5TokenizerRequest, flags: FTS5TokenizeFlags) throws -> [String] {
            let tokenizer = try makeTokenizer(tokenizer)
            
            return try ContiguousArray(string.utf8).withUnsafeBufferPointer { buffer -> [String] in
                guard let addr = buffer.baseAddress else {
                    return []
                }
                let pText = UnsafeMutableRawPointer(mutating: addr).assumingMemoryBound(to: Int8.self)
                let nText = Int32(buffer.count)
                
                var context = TokenizeContext()
                try withUnsafeMutablePointer(to: &context) { contextPointer in
                    let code = tokenizer.tokenize(UnsafeMutableRawPointer(contextPointer), flags, pText, nText, { (contextPointer, flags, pToken, nToken, iStart, iEnd) -> Int32 in
                        guard let contextPointer = contextPointer else { return SQLITE_ERROR }
                        
                        // Extract token
                        guard let token = pToken.flatMap({ String(data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: $0), count: Int(nToken), deallocator: .none), encoding: .utf8) }) else {
                            return SQLITE_OK
                        }
                        
                        contextPointer.assumingMemoryBound(to: TokenizeContext.self).pointee.tokens.append(token)
                        return SQLITE_OK
                    })
                    if (code != SQLITE_OK) {
                        throw DatabaseError(code: code)
                    }
                }
                return context.tokens
            }
        }

    }
#endif
