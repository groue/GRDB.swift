#if SQLITE_ENABLE_FTS5
import Foundation

/// Flags that tell SQLite how to register a token.
///
/// See the `FTS5_TOKEN_*` constants in <https://www.sqlite.org/fts5.html#custom_tokenizers>.
public struct FTS5TokenFlags: OptionSet {
    public let rawValue: CInt
    
    public init(rawValue: CInt) {
        self.rawValue = rawValue
    }
    
    /// `FTS5_TOKEN_COLOCATED`
    public static let colocated = FTS5TokenFlags(rawValue: FTS5_TOKEN_COLOCATED)
}

/// A function that lets FTS5WrapperTokenizer notify tokens.
///
/// See FTS5WrapperTokenizer.accept(token:flags:tokenCallback:)
public typealias FTS5WrapperTokenCallback = (_ token: String, _ flags: FTS5TokenFlags) throws -> Void

/// A type that implements a custom tokenizer for the ``FTS5`` full-text engine
/// by wrapping another tokenizer.
///
/// See [FTS5 Tokenizers](https://github.com/groue/GRDB.swift/blob/master/Documentation/FTS5Tokenizers.md)
/// for more information.
///
/// ## Topics
///
/// ### Tokenizing Text
///
/// - ``accept(token:flags:for:tokenCallback:)``
/// - ``FTS5WrapperTokenCallback``
public protocol FTS5WrapperTokenizer: FTS5CustomTokenizer {
    /// The wrapped tokenizer
    var wrappedTokenizer: any FTS5Tokenizer { get }
    
    /// Given a token produced by the wrapped tokenizer, notifies customized
    /// tokens to the `tokenCallback` function.
    ///
    /// For example:
    ///
    /// ```swift
    /// func accept(
    ///     token: String,
    ///     flags: FTS5TokenFlags,
    ///     for tokenization: FTS5Tokenization,
    ///     tokenCallback: FTS5WrapperTokenCallback
    /// ) throws {
    ///     // pass through:
    ///     try tokenCallback(token, flags)
    /// }
    /// ```
    ///
    /// When implementing the accept method, there are a two rules
    /// to observe:
    ///
    /// 1. Errors thrown by the tokenCallback function must not be caught.
    ///
    /// 2. The input `flags` should be given unmodified to the tokenCallback
    /// function, unless you union it with the ``FTS5TokenFlags/colocated`` flag
    /// when the tokenizer produces synonyms (see
    /// <https://www.sqlite.org/fts5.html#synonym_support>).
    ///
    /// - parameters:
    ///     - token: A token produced by the wrapped tokenizer
    ///     - flags: Flags that tell SQLite how to register a token.
    ///     - tokenization: The reason why FTS5 is requesting tokenization.
    ///     - tokenCallback: The function to call for each customized token.
    func accept(
        token: String,
        flags: FTS5TokenFlags,
        for tokenization: FTS5Tokenization,
        tokenCallback: FTS5WrapperTokenCallback)
    throws
}

private struct FTS5WrapperContext {
    let tokenizer: any FTS5WrapperTokenizer
    let context: UnsafeMutableRawPointer?
    let tokenization: FTS5Tokenization
    let tokenCallback: FTS5TokenCallback
}

extension FTS5WrapperTokenizer {
    public func tokenize(
        context: UnsafeMutableRawPointer?,
        tokenization: FTS5Tokenization,
        pText: UnsafePointer<Int8>?,
        nText: CInt,
        tokenCallback: @escaping FTS5TokenCallback)
    -> CInt
    {
        // `tokenCallback` is @convention(c). This requires a little setup
        // in order to transfer context.
        var customContext = FTS5WrapperContext(
            tokenizer: self,
            context: context,
            tokenization: tokenization,
            tokenCallback: tokenCallback)
        return withUnsafeMutablePointer(to: &customContext) { customContextPointer in
            // Invoke wrappedTokenizer
            return wrappedTokenizer.tokenize(
                context: customContextPointer,
                tokenization: tokenization,
                pText: pText,
                nText: nText) { (customContextPointer, tokenFlags, pToken, nToken, iStart, iEnd) in
                
                // Extract token produced by wrapped tokenizer
                guard let token = pToken.flatMap({ String(
                                                    data: Data(
                                                        bytesNoCopy: UnsafeMutableRawPointer(mutating: $0),
                                                        count: Int(nToken),
                                                        deallocator: .none),
                                                    encoding: .utf8) })
                else {
                    return SQLITE_OK // 0 // SQLITE_OK
                }
                
                // Extract context
                let customContext = customContextPointer!.assumingMemoryBound(to: FTS5WrapperContext.self).pointee
                let tokenizer = customContext.tokenizer
                let context = customContext.context
                let tokenization = customContext.tokenization
                let tokenCallback = customContext.tokenCallback
                
                // Process token produced by wrapped tokenizer
                do {
                    try tokenizer.accept(
                        token: token,
                        flags: FTS5TokenFlags(rawValue: tokenFlags),
                        for: tokenization,
                        tokenCallback: { (token, flags) in
                            // Turn token into bytes
                            return try ContiguousArray(token.utf8).withUnsafeBufferPointer { buffer in
                                guard let addr = buffer.baseAddress else {
                                    return
                                }
                                let pToken = UnsafeMutableRawPointer(mutating: addr)
                                    .assumingMemoryBound(to: Int8.self)
                                let nToken = CInt(buffer.count)
                                
                                // Inject token bytes into SQLite
                                let code = tokenCallback(context, flags.rawValue, pToken, nToken, iStart, iEnd)
                                guard code == SQLITE_OK else {
                                    throw DatabaseError(resultCode: code, message: "token callback failed")
                                }
                            }
                        })
                    
                    return SQLITE_OK
                } catch let error as DatabaseError {
                    return error.extendedResultCode.rawValue
                } catch {
                    return SQLITE_ERROR
                }
            }
        }
    }
}
#endif
