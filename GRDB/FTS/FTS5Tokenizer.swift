#if SQLITE_ENABLE_FTS5
// Import C SQLite functions
#if SWIFT_PACKAGE
import GRDBSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import Foundation

/// A low-level SQLite function that lets FTS5Tokenizer notify tokens.
///
/// See ``FTS5Tokenizer/tokenize(context:tokenization:pText:nText:tokenCallback:)``.
public typealias FTS5TokenCallback = @convention(c) (
    _ context: UnsafeMutableRawPointer?,
    _ flags: CInt,
    _ pToken: UnsafePointer<CChar>?,
    _ nToken: CInt,
    _ iStart: CInt,
    _ iEnd: CInt)
    -> CInt

/// The reason why FTS5 is requesting tokenization.
///
/// See the `FTS5_TOKENIZE_*` constants in <https://www.sqlite.org/fts5.html#custom_tokenizers>.
public struct FTS5Tokenization: OptionSet, Sendable {
    public let rawValue: CInt
    
    public init(rawValue: CInt) {
        self.rawValue = rawValue
    }
    
    /// `FTS5_TOKENIZE_QUERY`
    public static lazy var query = FTS5Tokenization(rawValue: FTS5_TOKENIZE_QUERY)
    
    /// `FTS5_TOKENIZE_PREFIX`
    public static let prefix = FTS5Tokenization(rawValue: FTS5_TOKENIZE_PREFIX)
    
    /// `FTS5_TOKENIZE_DOCUMENT`
    public static let document = FTS5Tokenization(rawValue: FTS5_TOKENIZE_DOCUMENT)
    
    /// `FTS5_TOKENIZE_AUX`
    public static let aux = FTS5Tokenization(rawValue: FTS5_TOKENIZE_AUX)
}

/// A type that implements a tokenizer for the ``FTS5`` full-text engine.
///
/// You can instantiate tokenizers, including
/// [built-in tokenizers](https://www.sqlite.org/fts5.html#tokenizers),
/// with the ``Database/makeTokenizer(_:)`` method:
///
/// ```swift
/// try dbQueue.read { db in
///     let unicode61 = try db.makeTokenizer(.unicode61()) // FTS5Tokenizer
/// }
/// ```
///
/// See [FTS5 Tokenizers](https://github.com/groue/GRDB.swift/blob/master/Documentation/FTS5Tokenizers.md)
/// for more information.
///
/// ## Topics
///
/// ### Tokenizing Text
///
/// - ``tokenize(document:)``
/// - ``tokenize(query:)``
/// - ``tokenize(context:tokenization:pText:nText:tokenCallback:)``
/// - ``FTS5TokenCallback``
public protocol FTS5Tokenizer: AnyObject {
    /// Tokenizes the text described by `pText` and `nText`, and
    /// notifies found tokens to the `tokenCallback` function.
    ///
    /// It matches the `xTokenize` function documented at <https://www.sqlite.org/fts5.html#custom_tokenizers>
    ///
    /// - parameters:
    ///     - context: An opaque pointer that is the first argument to
    ///       the `tokenCallback` function
    ///     - tokenization: The reason why FTS5 is requesting tokenization.
    ///     - pText: The tokenized text bytes. May or may not be
    ///       nul-terminated.
    ///     - nText: The number of bytes in the tokenized text.
    ///     - tokenCallback: The function to call for each found token.
    ///       It matches the `xToken` callback at <https://www.sqlite.org/fts5.html#custom_tokenizers>
    func tokenize(
        context: UnsafeMutableRawPointer?,
        tokenization: FTS5Tokenization,
        pText: UnsafePointer<CChar>?,
        nText: CInt,
        tokenCallback: @escaping FTS5TokenCallback)
    -> CInt
}

private class TokenizeContext {
    var tokens: [(String, FTS5TokenFlags)] = []
}

extension FTS5Tokenizer {
    
    /// Tokenizes the string argument as a document that would be inserted into
    /// an FTS5 table.
    ///
    /// For example:
    ///
    /// ```swift
    /// let tokenizer = try db.makeTokenizer(.ascii())
    /// try tokenizer.tokenize(document: "foo bar") // [("foo", flags), ("bar", flags)]
    /// ```
    ///
    /// See also `tokenize(query:)`.
    ///
    /// - parameter string: The string to tokenize.
    /// - returns: An array of tokens and flags.
    /// - throws: An error if tokenization fails.
    public func tokenize(document string: String) throws -> [(token: String, flags: FTS5TokenFlags)] {
        try tokenize(string, for: .document)
    }

    /// Tokenizes the string argument as an FTS5 query.
    ///
    /// For example:
    ///
    /// ```swift
    /// let tokenizer = try db.makeTokenizer(.ascii())
    /// try tokenizer.tokenize(query: "foo bar") // [("foo", flags), ("bar", flags)]
    /// ```
    ///
    /// See also `tokenize(document:)`.
    ///
    /// - parameter string: The string to tokenize.
    /// - returns: An array of tokens and flags.
    /// - throws: An error if tokenization fails.
    public func tokenize(query string: String) throws -> [(token: String, flags: FTS5TokenFlags)] {
        try tokenize(string, for: .query)
    }

    /// Tokenizes the string argument.
    ///
    ///     let tokenizer = try db.makeTokenizer(.ascii())
    ///     try tokenizer.tokenize("foo bar", for: .document) // [("foo", flags), ("bar", flags)]
    ///
    /// - parameter string: The string to tokenize
    /// - parameter tokenization: The reason why tokenization is requested:
    ///     - .document: Tokenize like a document being inserted into an FTS table.
    ///     - .query: Tokenize like the search pattern of the MATCH operator.
    /// - parameter tokenizer: A FTS5TokenizerDescriptor such as .ascii()
    private func tokenize(_ string: String, for tokenization: FTS5Tokenization)
    throws -> [(token: String, flags: FTS5TokenFlags)]
    {
        try ContiguousArray(string.utf8).withUnsafeBufferPointer { buffer -> [(String, FTS5TokenFlags)] in
            guard let addr = buffer.baseAddress else {
                return []
            }
            let pText = UnsafeMutableRawPointer(mutating: addr).assumingMemoryBound(to: CChar.self)
            let nText = CInt(buffer.count)
            
            var context = TokenizeContext()
            try withUnsafeMutablePointer(to: &context) { contextPointer in
                let code = tokenize(
                    context: UnsafeMutableRawPointer(contextPointer),
                    tokenization: tokenization,
                    pText: pText,
                    nText: nText,
                    tokenCallback: { (contextPointer, flags, pToken, nToken, _ /* iStart */, _ /* iEnd */) in
                        guard let contextPointer else {
                            return SQLITE_ERROR
                        }
                        
                        // Extract token
                        guard let token = pToken.flatMap({ String(
                                                            data: Data(
                                                                bytesNoCopy: UnsafeMutableRawPointer(mutating: $0),
                                                                count: Int(nToken),
                                                                deallocator: .none),
                                                            encoding: .utf8) })
                        else {
                            return SQLITE_OK
                        }
                        
                        let context = contextPointer.assumingMemoryBound(to: TokenizeContext.self).pointee
                        context.tokens.append((token, FTS5TokenFlags(rawValue: flags)))
                        return SQLITE_OK
                    })
                if code != SQLITE_OK {
                    throw DatabaseError(resultCode: code)
                }
            }
            return context.tokens
        }
    }
}

extension Database {
    
    // MARK: - FTS5
    
    /// Private type that makes a pre-registered FTS5 tokenizer available
    /// through the FTS5Tokenizer protocol.
    private final class FTS5RegisteredTokenizer: FTS5Tokenizer {
        let xTokenizer: fts5_tokenizer
        let tokenizerPointer: OpaquePointer
        
        init(xTokenizer: fts5_tokenizer, contextPointer: UnsafeMutableRawPointer?, arguments: [String]) throws {
            guard let xCreate = xTokenizer.xCreate else {
                throw DatabaseError(message: "nil fts5_tokenizer.xCreate")
            }
            
            self.xTokenizer = xTokenizer
            
            var tokenizerPointer: OpaquePointer? = nil
            let code: CInt
            if arguments.isEmpty {
                code = xCreate(contextPointer, nil, 0, &tokenizerPointer)
            } else {
                func withArrayOfCStrings<Result>(
                    _ input: [String],
                    _ output: inout ContiguousArray<UnsafePointer<CChar>>,
                    _ accessor: (ContiguousArray<UnsafePointer<CChar>>) -> Result)
                -> Result
                {
                    if output.count == input.count {
                        return accessor(output)
                    } else {
                        return input[output.count].withCString { (cString) -> Result in
                            output.append(cString)
                            return withArrayOfCStrings(input, &output, accessor)
                        }
                    }
                }
                var cStrings = ContiguousArray<UnsafePointer<CChar>>()
                cStrings.reserveCapacity(arguments.count)
                code = withArrayOfCStrings(arguments, &cStrings) { (cStrings) in
                    cStrings.withUnsafeBufferPointer { azArg in
                        xCreate(
                            contextPointer,
                            UnsafeMutablePointer(OpaquePointer(azArg.baseAddress!)),
                            CInt(cStrings.count),
                            &tokenizerPointer)
                    }
                }
            }
            
            guard code == SQLITE_OK else {
                throw DatabaseError(resultCode: code, message: "failed fts5_tokenizer.xCreate")
            }
            
            if let tokenizerPointer {
                self.tokenizerPointer = tokenizerPointer
            } else {
                throw DatabaseError(resultCode: code, message: "nil tokenizer")
            }
        }
        
        deinit {
            if let delete = xTokenizer.xDelete {
                delete(tokenizerPointer)
            }
        }
        
        func tokenize(
            context: UnsafeMutableRawPointer?,
            tokenization: FTS5Tokenization,
            pText: UnsafePointer<CChar>?,
            nText: CInt,
            tokenCallback: @escaping FTS5TokenCallback)
        -> CInt
        {
            guard let xTokenize = xTokenizer.xTokenize else {
                return SQLITE_ERROR
            }
            return xTokenize(tokenizerPointer, context, tokenization.rawValue, pText, nText, tokenCallback)
        }
    }
    
    /// Creates an FTS5 tokenizer, given its descriptor.
    ///
    /// For example:
    ///
    /// ```swift
    /// let unicode61 = try db.makeTokenizer(.unicode61())
    /// ```
    ///
    /// You can use this method when you implement a custom wrapper tokenizer
    /// with ``FTS5WrapperTokenizer``:
    ///
    /// ```swift
    /// final class MyTokenizer : FTS5WrapperTokenizer {
    ///     var wrappedTokenizer: FTS5Tokenizer
    ///
    ///     init(db: Database, arguments: [String]) throws {
    ///         wrappedTokenizer = try db.makeTokenizer(.unicode61())
    ///     }
    /// }
    /// ```
    ///
    /// It is a programmer error to use the tokenizer outside of a protected
    /// database queue, or after the database has been closed.
    public func makeTokenizer(_ descriptor: FTS5TokenizerDescriptor) throws -> any FTS5Tokenizer {
        let api = FTS5.api(self)
        
        let xTokenizerPointer: UnsafeMutablePointer<fts5_tokenizer> = .allocate(capacity: 1)
        defer { xTokenizerPointer.deallocate() }
        
        let contextHandle: UnsafeMutablePointer<UnsafeMutableRawPointer?> = .allocate(capacity: 1)
        defer { contextHandle.deallocate() }
        
        let code = api.pointee.xFindTokenizer!(
            UnsafeMutablePointer(mutating: api),
            descriptor.name,
            contextHandle,
            xTokenizerPointer)
        
        guard code == SQLITE_OK else {
            throw DatabaseError(resultCode: code)
        }
        
        let contextPointer = contextHandle.pointee
        return try FTS5RegisteredTokenizer(
            xTokenizer: xTokenizerPointer.pointee,
            contextPointer: contextPointer,
            arguments: descriptor.arguments)
    }
}
#endif
