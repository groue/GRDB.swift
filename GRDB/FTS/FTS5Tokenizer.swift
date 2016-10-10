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
    
    public protocol FTS5CustomTokenizer : FTS5Tokenizer {
        static var name: String { get }
        init(db: Database, arguments: [String]) throws
    }
    
    public struct FTS5TokenFlags : OptionSet {
        public let rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        /// FTS5_TOKEN_COLOCATED
        public static let colocated = FTS5TokenFlags(rawValue: FTS5_TOKEN_COLOCATED)
    }
    
    public typealias FTS5TokenNotifier = (_ token: String, _ flags: FTS5TokenFlags) throws -> ()
    
    public protocol FTS5WrapperTokenizer : FTS5CustomTokenizer {
        var wrappedTokenizer: FTS5Tokenizer { get }
        func customizesWrappedTokenizer(flags: FTS5TokenizeFlags) -> Bool
        func accept(token: String, flags: FTS5TokenFlags, notify: FTS5TokenNotifier) throws
    }
    
    private struct FTS5WrapperContext {
        let tokenizer: FTS5WrapperTokenizer
        let context: UnsafeMutableRawPointer?
        let xToken: FTS5TokenCallback
    }
    
    extension FTS5CustomTokenizer {
        public static func tokenizer(arguments: [String] = []) -> FTS5TokenizerDefinition {
            return FTS5TokenizerDefinition(components: [name] + arguments)
        }
    }
    
    extension FTS5WrapperTokenizer {
        public func tokenize(_ context: UnsafeMutableRawPointer?, _ flags: FTS5TokenizeFlags, _ pText: UnsafePointer<Int8>?, _ nText: Int32, _ xToken: FTS5TokenCallback?) -> Int32 {
            // Let wrappedTokenizer do the job unless we customize
            guard customizesWrappedTokenizer(flags: flags) else {
                return wrappedTokenizer.tokenize(context, flags, pText, nText, xToken)
            }
            
            // The xToken callback is @convention(c). This requires a little setup
            // in order to transfer context.
            var customContext = FTS5WrapperContext(tokenizer: self, context: context, xToken: xToken!)
            return withUnsafeMutablePointer(to: &customContext) { customContextPointer in
                // Invoke wrappedTokenizer
                return wrappedTokenizer.tokenize(customContextPointer, flags, pText, nText) { (customContextPointer, flags, pToken, nToken, iStart, iEnd) in
                    
                    // Extract token produced by wrapped tokenizer
                    guard let token = pToken.flatMap({ String(data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: $0), count: Int(nToken), deallocator: .none), encoding: .utf8) }) else {
                        return 0 // SQLITE_OK
                    }
                    
                    // Extract context
                    let customContext = customContextPointer!.assumingMemoryBound(to: FTS5WrapperContext.self).pointee
                    let tokenizer = customContext.tokenizer
                    let context = customContext.context
                    let xToken = customContext.xToken
                    
                    // Process token produced by wrapped tokenizer
                    do {
                        try tokenizer.accept(token: token, flags: FTS5TokenFlags(rawValue: flags), notify: { (token, flags) in
                            // Turn token into bytes
                            return try ContiguousArray(token.utf8).withUnsafeBufferPointer { buffer in
                                guard let addr = buffer.baseAddress else {
                                    return
                                }
                                let pToken = UnsafeMutableRawPointer(mutating: addr).assumingMemoryBound(to: Int8.self)
                                let nToken = Int32(buffer.count)
                                
                                // Inject token into SQLite
                                let code = xToken(context, flags.rawValue, pToken, nToken, iStart, iEnd)
                                guard code == SQLITE_OK else {
                                    throw DatabaseError(code: code, message: "failed xToken")
                                }
                            }
                        })
                        
                        return SQLITE_OK
                    } catch let error as DatabaseError {
                        return error.code
                    } catch {
                        return SQLITE_ERROR
                    }
                }
            }
        }
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
        
        private class FTS5TokenizerCreationContext {
            let db: Database
            let constructor: (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> Int32
            
            init(db: Database, constructor: @escaping (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> Int32) {
                self.db = db
                self.constructor = constructor
            }
        }
        
        private var fts5api: UnsafePointer<fts5_api>? {
            return Data
                .fetchOne(self, "SELECT fts5()")
                .flatMap { data in
                    guard data.count == MemoryLayout<UnsafePointer<fts5_api>>.size else { return nil }
                    return data.withUnsafeBytes { (api: UnsafePointer<UnsafePointer<fts5_api>>) in api.pointee }
            }
        }
        
        public func makeTokenizer(_ tokenizer: FTS5TokenizerDefinition) throws -> FTS5Tokenizer {
            guard let api = fts5api else {
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
        
        public func add<Tokenizer: FTS5CustomTokenizer>(tokenizer: Tokenizer.Type) {
            guard let api = fts5api else {
                fatalError("FTS5 is not enabled")
            }
            
            // Hides the generic Tokenizer type from the @convention(c) xCreate function.
            let context = FTS5TokenizerCreationContext(
                db: self,
                constructor: { (db, arguments, tokenizerHandle) in
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
            
            var xTokenizer = fts5_tokenizer(
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
                xTokenize: { (tokenizerPointer, context, flags, pText, nText, xToken) -> Int32 in
                    guard let tokenizerPointer = tokenizerPointer else {
                        return SQLITE_ERROR
                    }
                    let object = Unmanaged<AnyObject>.fromOpaque(UnsafeMutableRawPointer(tokenizerPointer)).takeUnretainedValue()
                    let tokenizer = object as! FTS5Tokenizer
                    return tokenizer.tokenize(context, FTS5TokenizeFlags(rawValue: flags), pText, nText, xToken)
            })
            
            let contextPointer = Unmanaged.passRetained(context).toOpaque()
            let code = withUnsafeMutablePointer(to: &xTokenizer) { xTokenizerPointer in
                api.pointee.xCreateTokenizer(
                    UnsafeMutablePointer(mutating: api),
                    Tokenizer.name,
                    contextPointer,
                    xTokenizerPointer,
                    { contextPointer in
                        if let contextPointer = contextPointer {
                            Unmanaged<FTS5TokenizerCreationContext>.fromOpaque(contextPointer).release()
                        }
                    }
                )
            }
            guard code == SQLITE_OK else {
                fatalError(DatabaseError(code: code, message: lastErrorMessage).description)
            }
        }
    }
    
    extension DatabaseQueue {
        public func add<Tokenizer: FTS5CustomTokenizer>(tokenizer: Tokenizer.Type) {
            inDatabase { db in
                db.add(tokenizer: Tokenizer.self)
            }
        }
    }
    
    extension DatabasePool {
        public func add<Tokenizer: FTS5CustomTokenizer>(tokenizer: Tokenizer.Type) {
            write { db in
                db.add(tokenizer: Tokenizer.self)
            }
        }
    }
#endif
