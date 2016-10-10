#if SQLITE_ENABLE_FTS5
    public protocol FTS5CustomTokenizer : FTS5Tokenizer {
        static var name: String { get }
        init(db: Database, arguments: [String]) throws
    }
    
    extension Database {
        private class FTS5TokenizerConstructor {
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
            
            // Swift won't let the @convention(c) xCreate() function below create
            // an instance of the generic Tokenizer type.
            //
            // We thus hide the generic Tokenizer type inside a neutral type:
            // FTS5TokenizerConstructor
            let constructor = FTS5TokenizerConstructor(
                db: self,
                constructor: { (db, arguments, tokenizerHandle) in
                    guard let tokenizerHandle = tokenizerHandle else {
                        return SQLITE_ERROR
                    }
                    do {
                        let tokenizer = try Tokenizer(db: db, arguments: arguments)
                        
                        // Tokenizer must remain alive until releaseTokenizer() is
                        // called, as the xDelete member of xTokenizer
                        let tokenizerPointer = OpaquePointer(Unmanaged.passRetained(tokenizer).toOpaque())
                        
                        tokenizerHandle.pointee = tokenizerPointer
                        return SQLITE_OK
                    } catch let error as DatabaseError {
                        return error.code
                    } catch {
                        return SQLITE_ERROR
                    }
            })
            
            // Constructor must remain alive until releaseConstructor() is
            // called, as the last argument of the xCreateTokenizer() function.
            let constructorPointer = Unmanaged.passRetained(constructor).toOpaque()
            
            func releaseConstructor(constructorPointer: UnsafeMutableRawPointer?) {
                guard let constructorPointer = constructorPointer else { return }
                Unmanaged<AnyObject>.fromOpaque(constructorPointer).release()
            }
            
            func releaseTokenizer(tokenizerPointer: OpaquePointer?) {
                guard let tokenizerPointer = tokenizerPointer else { return }
                Unmanaged<AnyObject>.fromOpaque(UnsafeMutableRawPointer(tokenizerPointer)).release()
            }
            
            var xTokenizer = fts5_tokenizer(
                xCreate: { (constructorPointer, azArg, nArg, tokenizerHandle) -> Int32 in
                    guard let constructorPointer = constructorPointer else {
                        return SQLITE_ERROR
                    }
                    let constructor = Unmanaged<FTS5TokenizerConstructor>.fromOpaque(constructorPointer).takeUnretainedValue()
                    var arguments: [String] = []
                    if let azArg = azArg {
                        for i in 0..<Int(nArg) {
                            if let cstr = azArg[i] {
                                arguments.append(String(cString: cstr))
                            }
                        }
                    }
                    return constructor.constructor(constructor.db, arguments, tokenizerHandle)
                },
                xDelete: releaseTokenizer,
                xTokenize: { (tokenizerPointer, context, flags, pText, nText, xToken) -> Int32 in
                    guard let tokenizerPointer = tokenizerPointer else {
                        return SQLITE_ERROR
                    }
                    let object = Unmanaged<AnyObject>.fromOpaque(UnsafeMutableRawPointer(tokenizerPointer)).takeUnretainedValue()
                    guard let tokenizer = object as? FTS5Tokenizer else {
                        return SQLITE_ERROR
                    }
                    return tokenizer.tokenize(context, FTS5TokenizeFlags(rawValue: flags), pText, nText, xToken)
            })
            
            let code = withUnsafeMutablePointer(to: &xTokenizer) { xTokenizerPointer in
                api.pointee.xCreateTokenizer(UnsafeMutablePointer(mutating: api), Tokenizer.name, constructorPointer, xTokenizerPointer, releaseConstructor)
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
