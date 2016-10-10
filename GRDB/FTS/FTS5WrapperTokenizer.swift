#if SQLITE_ENABLE_FTS5
    /// Flags that tell SQLite how to register a token.
    ///
    /// See https://www.sqlite.org/fts5.html#custom_tokenizers
    public struct FTS5TokenFlags : OptionSet {
        public let rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        /// FTS5_TOKEN_COLOCATED
        public static let colocated = FTS5TokenFlags(rawValue: FTS5_TOKEN_COLOCATED)
    }
    
    /// A function that lets tokenizers notify tokens.
    public typealias FTS5WrapperTokenCallback = (_ token: String, _ flags: FTS5TokenFlags) throws -> ()
    
    /// The protocol for custom FTS5 tokenizers that wrap another tokenizer.
    public protocol FTS5WrapperTokenizer : FTS5CustomTokenizer {
        /// The wrapped tokenizer
        var wrappedTokenizer: FTS5Tokenizer { get }
        
        /// Returns whether the tokens emitted by the wrapped tokenizer should
        /// be processed by `accept(token:flags:tokenCallback:)`.
        ///
        /// - parameter flags: Flags that indicate the reason why FTS5 is
        ///   requesting tokenization.
        func customizesWrappedTokenizer(flags: FTS5TokenizeFlags) -> Bool
        
        /// Given a token produced by the wrapped tokenizer, notifies custom
        /// tokens to the `tokenCallback` function.
        ///
        /// - parameters:
        ///     - token: A token produced by the wrapped tokenizer
        ///     - flags: Flags that tell SQLite how to register a token.
        ///     - tokenCallback: The function to call for each found token.
        func accept(token: String, flags: FTS5TokenFlags, tokenCallback: FTS5WrapperTokenCallback) throws
    }
    
    private struct FTS5WrapperContext {
        let tokenizer: FTS5WrapperTokenizer
        let context: UnsafeMutableRawPointer?
        let tokenCallback: FTS5TokenCallback
    }
    
    extension FTS5WrapperTokenizer {
        /// Default implementation
        public func tokenize(context: UnsafeMutableRawPointer?, flags: FTS5TokenizeFlags, pText: UnsafePointer<Int8>?, nText: Int32, tokenCallback: FTS5TokenCallback?) -> Int32 {
            // Let wrappedTokenizer do the job unless we customize
            guard customizesWrappedTokenizer(flags: flags) else {
                return wrappedTokenizer.tokenize(context: context, flags: flags, pText: pText, nText: nText, tokenCallback: tokenCallback)
            }
            
            // `tokenCallback` is @convention(c). This requires a little setup
            // in order to transfer context.
            var customContext = FTS5WrapperContext(tokenizer: self, context: context, tokenCallback: tokenCallback!)
            return withUnsafeMutablePointer(to: &customContext) { customContextPointer in
                // Invoke wrappedTokenizer
                return wrappedTokenizer.tokenize(context: customContextPointer, flags: flags, pText: pText, nText: nText) { (customContextPointer, flags, pToken, nToken, iStart, iEnd) in
                    
                    // Extract token produced by wrapped tokenizer
                    guard let token = pToken.flatMap({ String(data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: $0), count: Int(nToken), deallocator: .none), encoding: .utf8) }) else {
                        return 0 // SQLITE_OK
                    }
                    
                    // Extract context
                    let customContext = customContextPointer!.assumingMemoryBound(to: FTS5WrapperContext.self).pointee
                    let tokenizer = customContext.tokenizer
                    let context = customContext.context
                    let tokenCallback = customContext.tokenCallback
                    
                    // Process token produced by wrapped tokenizer
                    do {
                        try tokenizer.accept(token: token, flags: FTS5TokenFlags(rawValue: flags), tokenCallback: { (token, flags) in
                            // Turn token into bytes
                            return try ContiguousArray(token.utf8).withUnsafeBufferPointer { buffer in
                                guard let addr = buffer.baseAddress else {
                                    return
                                }
                                let pToken = UnsafeMutableRawPointer(mutating: addr).assumingMemoryBound(to: Int8.self)
                                let nToken = Int32(buffer.count)
                                
                                // Inject token into SQLite
                                let code = tokenCallback(context, flags.rawValue, pToken, nToken, iStart, iEnd)
                                guard code == SQLITE_OK else {
                                    throw DatabaseError(code: code, message: "token consumer failed")
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
#endif
