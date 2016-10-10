#if SQLITE_ENABLE_FTS5
    public protocol FTS5CustomTokenizer : FTS5Tokenizer {
        static var name: String { get }
        init(db: Database, arguments: [String]) throws
    }
    
    extension Database {
        private class FTS5TokenizerCreationContext {
            let db: Database
            let constructor: (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> Int32
            
            init(db: Database, constructor: @escaping (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> Int32) {
                self.db = db
                self.constructor = constructor
            }
        }
        
        public func add<Tokenizer: FTS5CustomTokenizer>(tokenizer: Tokenizer.Type) {
            guard let api = FTS5.api(self) else {
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
