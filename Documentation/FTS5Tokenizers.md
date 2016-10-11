FTS5 Tokenizers
===============

**[FTS5](https://www.sqlite.org/fts5.html) is an extensible full-text search engine.**

GRDB lets you define your own custom FST5 tokenizers, and extend SQLite built-in tokenizers. Possible use cases are:

- Have "fi" match the ligature "&#xfb01;" (U+FB01)
- Have "first" match "1st"
- Have "Encyclopaedia" match "Encyclopædia"
- Have "Mueller" match "Müller", and "Grossmann" match "Großmann"
- Have "romaji" match "ローマ字"
- Have "pinyin" match "拼音"
- Prevent "the" and other stop words from matching any document

**Table of Contents**

- [The Tokenizer Protocols](#the-tokenizer-protocols)
- [Using A Custom Tokenizer](#using-a-custom-tokenizer)
- [FTS5Tokenizer](#fts5tokenizer)
- [FTS5CustomTokenizer](#fts5customtokenizer)
- [FTS5WrapperTokenizer](#fts5wrappertokenizer)
    - [Choosing the Wrapped Tokenizer](#choosing-the-wrapped-tokenizer)
    - [Synonyms](#synonyms)


## The Tokenizer Protocols

- [FTS5Tokenizer](#fts5tokenizer): the protocol for all FTS5 tokenizers, including built-in tokenizers such as `ascii`, `unicode61`, and `porter`.
    
    - [FTS5CustomTokenizer](#fts5customtokenizer): the low-level protocol for all custom tokenizers, close to the FTS5 metal.
    
        - [FTS5WrapperTokenizer](#fts5wrappertokenizer): the high-level protocol for custom tokenizers that post-processes the tokens produced by another FTS5Tokenizer.


## Using A Custom Tokenizer

Once you have a type that implements FTS5CustomTokenizer or FTS5WrapperTokenizer, you register it into the database, and create full-text tables:

```swift
class MyTokenizer : FTS5CustomTokenizer { ... }

dbQueue.add(tokenizer: MyTokenizer.self) // or dbPool.add

dbQueue.inDatabase { db in
    try db.create(virtualTable: "documents", using: FTS5()) { t in
        t.tokenizer = MyTokenizer.tokenizerDescriptor()
        t.column("authors")
        t.column("title")
        t.column("body")
    }
}
```

And then the full-text table can be fed and queried in a regular way:

```swift
try Document(...).insert(db)
let documents = Document.matching(...).fetchAll(db)
```


## FTS5Tokenizer

**FST5Tokenizer** is the protocol for all FTS5 tokenizers: your custom ones, and also built-in tokenizers such as `ascii`, `unicode61`, and `porter`.

It only requires a tokenization method that matches the `xTokenize` C function documented at https://www.sqlite.org/fts5.html#custom_tokenizers. We'll discuss it more when describing custom tokenizers.

```swift
protocol FTS5Tokenizer : class {
    func tokenize(context: UnsafeMutableRawPointer?, flags: FTS5TokenizationFlags, pText: UnsafePointer<Int8>?, nText: Int32, tokenCallback: FTS5TokenCallback?) -> Int32
}
```

You can instantiate tokenizers with the Database.makeTokenizer() method:

```swift
let ascii = try db.makeTokenizer(.ascii()) // FTS5Tokenizer
```

Tokenizers can tokenize (and can produce different tokens depending on whether they are tokenizing a *document*, or a *query*):

```swift
let tokens = try ascii.tokenize("foo bar", flags: .query) // ["foo", "bar"]
```


## FTS5CustomTokenizer

**FTS5CustomTokenizer** is the low-level protocol for your custom tokenizers.

```swift
protocol FTS5CustomTokenizer : FTS5Tokenizer {
    static var name: String { get }
    init(db: Database, arguments: [String]) throws
}
```

Custom tokenizers have a name, like built-in tokenizers have a name. Don't use "ascii", "porter", or "unicode61" since they are already taken!

```swift
final class MyTokenizer : FTS5CustomTokenizer {
    static let name = "custom"
}
```

SQLite instantiates tokenizers when it needs tokens. The arguments parameter of the initializer is an array of strings, which your custom tokenizer can use, or not. In the example below, the arguments will be `["arg1", "arg2"]`.

```swift
// CREATE VIRTUAL TABLE documents USING fts5(
//     tokenize='custom arg1 arg2',
//     authors, title, body
// )
try db.create(virtualTable: "documents", using: FTS5()) { t in
    t.tokenizer = MyTokenizer.tokenizerDescriptor(arguments: ["arg1", "arg2"])
    t.column("authors")
    t.column("title")
    t.column("body")
}
```

FTS5CustomTokenizer inherits from [FTS5Tokenizer](#fts5tokenizer), and performs its tokenization job in its `tokenize(context:flags:pText:nText:tokenCallback:)` method. This low-level method matches the `xTokenize` function documented at https://www.sqlite.org/fts5.html#custom_tokenizers.

This method arguments are:

- `context`: An opaque pointer that is the first argument to the `tokenCallback` function
- `flags`: Flags that indicate the reason why FTS5 is requesting tokenization.
- `pText`: The tokenized text bytes. May or may not be nul-terminated.
- `nText`: The number of bytes in the tokenized text.
- `tokenCallback`: The function to call for each found token. It matches the `xToken` callback at https://www.sqlite.org/fts5.html#custom_tokenizers:
    - `context`: An opaque pointer
    - `flags`: Flags that tell FTS5 how to register the token
    - `pToken`: The token bytes. May or may not be nul-terminated.
    - `nToken`: The number of bytes in the token
    - `iStart`: Byte offset of token within input text
    - `iEnd`: Byte offset of end of token within input text

As an example, let's write a custom tokenizer that ignores arguments, and produces no token at all:

```swift
final class BlackHoleTokenizer : FTS5CustomTokenizer {
    static let name = "blackhole"
    
    init(db: Database, arguments: [String]) throws {
    }
    
    func tokenize(context: UnsafeMutableRawPointer?, flags: FTS5TokenizationFlags, pText: UnsafePointer<Int8>?, nText: Int32, tokenCallback: FTS5TokenCallback?) -> Int32 {
        return 0 // SQLITE_OK
    }
}
```

Since tokenization is hard, and pointers to bytes buffers uneasy to deal with, you may enjoy then [FTS5WrapperTokenizer](#fts5wrappertokenizer) protocol.


## FTS5WrapperTokenizer

**FTS5WrapperTokenizer** is the high-level protocol for your custom tokenizers.

With this protocol, a custom tokenizer post-processes the tokens produced by another tokenizer, the "wrapped tokenizer", and does not have to implement the dreadful low-level `tokenize(context:flags:pText:nText:tokenCallback:)` method.

```swift
protocol FTS5WrapperTokenizer : FTS5CustomTokenizer {
    var wrappedTokenizer: FTS5Tokenizer { get }
    func customizesTokenization(flags: FTS5TokenizationFlags) -> Bool
    func accept(token: String, flags: FTS5TokenFlags, tokenCallback: FTS5WrapperTokenCallback) throws
}
```

As all custom tokenizers, wrapper tokenizers must have a name:

```swift
final class MyTokenizer : FTS5WrapperTokenizer {
    static let name = "custom"
}
```

The `wrappedTokenizer` property is the wrapped tokenizer. You instantiate it in the initializer:

```swift
final class MyTokenizer : FTS5WrapperTokenizer {
    let wrappedTokenizer: FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        // Wrap the unicode61 tokenizer
        wrappedTokenizer = try db.makeTokenizer(.unicode61())
    }
}
```

Some wrapper tokenizers sometimes want to opt-out token customization (see [Synonyms](#synonyms)). Most of them return true from their customizesTokenization method:

```swift
final class MyTokenizer : FTS5WrapperTokenizer {
    func customizesTokenization(flags: FTS5TokenizationFlags) -> Bool {
        return true
    }
}
```

Finally, wrapper tokenizers can process tokens produced by their wrapped tokenizer. They can ignore tokens, modify tokens, and even notify several tokens to the FTS5 engine:

```swift
final class MyTokenizer : FTS5WrapperTokenizer {
    func accept(token: String, flags: FTS5TokenFlags, tokenCallback: FTS5WrapperTokenCallback) throws {
        // pass through
        try tokenCallback(token, flags)
    }
}
```

When implementing the accept method, there are a few rules to observe:

- Errors thrown by `tokenCallback` must not be caught.
- The input `flags` should be given unmodified to the tokenCallback function, with one exception: [synonyms tokens](#synonyms).


### Choosing the Wrapped Tokenizer

The wrapped tokenizer can be hard-coded, or provided through arguments.

For example, your custom tokenizer can wrap `unicode61`, unless arguments say otherwise (in a fashion similar to the [porter](https://www.sqlite.org/fts5.html#porter_tokenizer) tokenizer:

```swift
final class MyTokenizer : FTS5WrapperTokenizer {
    init(db: Database, arguments: [String]) throws {
        if arguments.isEmpty {
            wrappedTokenizer = try db.makeTokenizer(.unicode61())
        } else {
            wrappedTokenizer = try db.makeTokenizer(FTS5TokenizerDescriptor(components: arguments))
        }
    }
}
```

Arguments are provided when the virtual table is created:

```swift
try db.create(virtualTable: "documents", using: FTS5()) { t in
    // Wraps the default unicode61
    t.tokenizer = MyTokenizer.tokenizerDescriptor()
}

try db.create(virtualTable: "documents", using: FTS5()) { t in
    // Wraps ascii
    let ascii = FTS5TokenizerDescriptor.ascii()
    t.tokenizer = MyTokenizer.tokenizerDescriptor(arguments: ascii.components)
    t.column("content")
}
```


### Synonyms

TODO
