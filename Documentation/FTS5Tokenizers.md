FTS5 Tokenizers
===============

**[FTS5](https://www.sqlite.org/fts5.html) is an extensible full-text search engine.**

GRDB lets you define your own custom FST5 tokenizers, and extend SQLite built-in tokenizers. Possible use cases are:

- Have "fi" match the ligature "&#xfb01;" (U+FB01)
- Have "first" match "1st"
- Have "Encyclopaedia" match "Encyclopædia"
- Have "Mueller" match "Müller", and "Grossmann" match "Großmann"
- Have "romaji" match "ローマ字", and "pinyin" match "拼音"
- Prevent "the" and other stop words from matching any document

**Table of Contents**

- [Tokenizers and Full-Text Search](#tokenizers-and-full-text-search)
- [The Tokenizer Protocols](#the-tokenizer-protocols)
- [Using a Custom Tokenizer](#using-a-custom-tokenizer)
- [FTS5Tokenizer](#fts5tokenizer)
- [FTS5CustomTokenizer](#fts5customtokenizer)
- [FTS5WrapperTokenizer](#fts5wrappertokenizer)
    - [Choosing the Wrapped Tokenizer](#choosing-the-wrapped-tokenizer)
- [Example: Synonyms](#example-synonyms)
- [Example: Latin Script](#example-latin-script)


## Tokenizers and Full-Text Search

**A Tokenizer splits text into tokens**. For example, a tokenizer can split "SQLite is a database engine" into the five tokens "SQLite", "is", "a", "database", and "engine".

FTS5 use tokenizers to tokenize both indexed documents and search patterns. **A match between a document and a search pattern happens when both produce *identical* tokens.**

All SQLite [built-in tokenizers](https://www.sqlite.org/fts5.html#tokenizers) tokenize both "SQLite" and "sqlite" into the common lowercase token "sqlite". This is why they are case-insensitive. Generally speaking, different tokenizers achieve different matching by applying different transformations to the input text.

- The [ascii](https://www.sqlite.org/fts5.html#ascii_tokenizer) tokenizer turns all ASCII characters to lowercase. "SQLite is a database engine" gives "sqlite", "is", "a", "database", and "engine". The query "SQLITE DATABASE" will match, because its tokens "sqlite" and "database" are found in the document.

- The [unicode61](https://www.sqlite.org/fts5.html#unicode61_tokenizer) tokenizer remove diacritics from latin characters. Unlike the ascii tokenizer, it will match "Jérôme" with "Jerome", as both produce the same "jerome" token.

- The [porter](https://www.sqlite.org/fts5.html#porter_tokenizer) tokenizer turns English words into their root: "database engine" gives the "databas" and "engin" tokens. The query "database engines" will match, because it produces the same tokens.

However, built-in tokenizers don't match "first" with "1st", because they produce the different "first" and "1st" tokens.

Nor do they match "Grossmann" with "Großmann", because they produce the different "grossmann" and "großmann" tokens.

Custom tokenizers help dealing with these situations. We'll see how to match "Grossmann" and "Großmann" by tokenizing them into "grossmann" (see [latin script](#example-latin-script)). We'll also see how to have "first" and "1st" emit *synonym tokens*, so that they can match too (see [synonyms](#example-synonyms)).


## The Tokenizer Protocols

GRDB lets you use and define FTS5 tokenizers through three protocols:

- [FTS5Tokenizer](#fts5tokenizer): the protocol for all FTS5 tokenizers, including the [built-in tokenizers](https://www.sqlite.org/fts5.html#tokenizers) ascii, unicode61, and porter.
    
    - [FTS5CustomTokenizer](#fts5customtokenizer): the low-level protocol that lets custom tokenizers use the raw [FTS5 C API](https://www.sqlite.org/fts5.html#custom_tokenizers).
    
        - [FTS5WrapperTokenizer](#fts5wrappertokenizer): the high-level protocol for custom tokenizers that post-processes the tokens produced by another FTS5Tokenizer.


## Using a Custom Tokenizer

Once you have a custom tokenizer type that adopts [FTS5CustomTokenizer](#fts5customtokenizer) or [FTS5WrapperTokenizer](#fts5wrappertokenizer), it can fuel the FTS5 engine.

**Register the custom tokenizer into the database:**

```swift
class MyTokenizer : FTS5CustomTokenizer { ... }

dbQueue.add(tokenizer: MyTokenizer.self) // or dbPool.add
```

**Create [full-text tables](../../../#create-fts5-virtual-tables) that use the custom tokenizer:**

```swift
try db.create(virtualTable: "documents", using: FTS5()) { t in
    t.tokenizer = MyTokenizer.tokenizerDescriptor()
    t.column("content")
}
```

The full-text table can be fed and queried in [a regular way](../../../#full-text-search):

```swift
try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["..."])
try Document(content: "...").insert(db)

let pattern = FTS5Pattern(matchingAnyTokenIn:"...")
let documents = try Document.matching(pattern).fetchAll(db)
```


## FTS5Tokenizer

**FST5Tokenizer** is the protocol for all FTS5 tokenizers.

It only requires a tokenization method that matches the low-level `xTokenize` C function documented at https://www.sqlite.org/fts5.html#custom_tokenizers. We'll discuss it more when describing custom tokenizers.

```swift
typealias FTS5TokenCallback = @convention(c) (
    _ context: UnsafeMutableRawPointer?,
    _ flags: Int32,
    _ pToken: UnsafePointer<Int8>?,
    _ nToken: Int32,
    _ iStart: Int32,
    _ iEnd: Int32) -> Int32

protocol FTS5Tokenizer : class {
    func tokenize(
        context: UnsafeMutableRawPointer?,
        tokenization: FTS5Tokenization,
        pText: UnsafePointer<Int8>?,
        nText: Int32,
        tokenCallback: FTS5TokenCallback?) -> Int32
}
```

You can instantiate tokenizers, including [built-in tokenizers](https://www.sqlite.org/fts5.html#tokenizers), with the `Database.makeTokenizer()` method:

```swift
let unicode61 = try db.makeTokenizer(.unicode61()) // FTS5Tokenizer
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

SQLite instantiates tokenizers when it needs tokens. The arguments parameter of the `init(db:arguments:)` initializer is an array of strings, which your custom tokenizer can use for its own purposes. In the example below, the arguments will be `["arg1", "arg2"]`.

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

FTS5CustomTokenizer inherits from [FTS5Tokenizer](#fts5tokenizer), and performs tokenization with its `tokenize(context:tokenization:pText:nText:tokenCallback:)` method. This low-level method matches the `xTokenize` C function documented at https://www.sqlite.org/fts5.html#custom_tokenizers.

This method arguments are:

- `context`: An opaque pointer that is the first argument to the `tokenCallback` function
- `tokenization`: The reason why FTS5 is requesting tokenization.
- `pText`: The tokenized text bytes. May or may not be nul-terminated.
- `nText`: The number of bytes in the tokenized text.
- `tokenCallback`: The function to call for each found token. It matches the `xToken` callback at https://www.sqlite.org/fts5.html#custom_tokenizers:
    - `context`: An opaque pointer
    - `flags`: Flags that tell FTS5 how to register the token
    - `pToken`: The token bytes. May or may not be nul-terminated.
    - `nToken`: The number of bytes in the token
    - `iStart`: Byte offset of token within input text
    - `iEnd`: Byte offset of end of token within input text

Since tokenization is hard, and pointers to byte buffers uneasy to deal with, you may enjoy the [FTS5WrapperTokenizer](#fts5wrappertokenizer) protocol.


## FTS5WrapperTokenizer

**FTS5WrapperTokenizer** is the high-level protocol for your custom tokenizers. It provides a default implementation for the low-level `tokenize(context:tokenization:pText:nText:tokenCallback:)` method, so that the adopting type does not have to deal with raw byte buffers of the raw [FTS5 C API](https://www.sqlite.org/fts5.html#custom_tokenizers).

A FTS5WrapperTokenizer lets the hard tokenization job to another tokenizer, the "wrapped tokenizer", and post-processes the tokens produced by this wrapped tokenizer.

```swift
protocol FTS5WrapperTokenizer : FTS5CustomTokenizer {
    var wrappedTokenizer: FTS5Tokenizer { get }
    func accept(
        token: String,
        flags: FTS5TokenFlags,
        for tokenization: FTS5Tokenization,
        tokenCallback: FTS5WrapperTokenCallback) throws
}
```

As all custom tokenizers, wrapper tokenizers must have a name:

```swift
final class MyTokenizer : FTS5WrapperTokenizer {
    static let name = "custom"
}
```

The `wrappedTokenizer` property is the mandatory wrapped tokenizer. You instantiate it once, in the initializer:

```swift
final class MyTokenizer : FTS5WrapperTokenizer {
    let wrappedTokenizer: FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        // Wrap the unicode61 tokenizer
        wrappedTokenizer = try db.makeTokenizer(.unicode61())
    }
}
```

Wrapper tokenizers have to implement the `accept(token:flags:for:tokenCallback:)` method.

For example, a tokenizer that simply passes tokens through gives:

```swift
final class MyTokenizer : FTS5WrapperTokenizer {
    func accept(
        token: String,
        flags: FTS5TokenFlags,
        for tokenization: FTS5Tokenization,
        tokenCallback: FTS5WrapperTokenCallback) throws
    {
        // pass through
        try tokenCallback(token, flags)
    }
}
```

The token argument is a token produced by the wrapped tokenizer, ready to be ignored, modified, or multiplied into several [synonyms](#example-synonyms).

The tokenization parameter tells the reason why tokens are produced, if FTS5 is tokenizing a document, or a search pattern. Some tokenizers may produce different tokens depending on this parameter.

Finally, the tokenCallback is a function you call to output a custom token.

There are a two rules to observe when implementing the accept method:

1. Errors thrown by the tokenCallback function must not be caught (they notify that FTS5 requires the tokenization process to stop immediately).
2. The flags parameter should be given unmodified to the tokenCallback function along with the custom token, unless you union it with the `.colocated` flag when the tokenizer produces [synonyms](#example-synonyms).


### Choosing the Wrapped Tokenizer

The wrapped tokenizer can be hard-coded, or chosen at runtime.

For example, your custom tokenizer can wrap [unicode61](https://www.sqlite.org/fts5.html#unicode61_tokenizer), unless arguments say otherwise (in a fashion similar to the [porter](https://www.sqlite.org/fts5.html#porter_tokenizer) tokenizer):

```swift
final class MyTokenizer : FTS5WrapperTokenizer {
    static let name = "custom"
    let wrappedTokenizer: FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        if arguments.isEmpty {
            wrappedTokenizer = try db.makeTokenizer(.unicode61())
        } else {
            let descriptor = FTS5TokenizerDescriptor(components: arguments)
            wrappedTokenizer = try db.makeTokenizer(descriptor)
        }
    }
}
```

Arguments are provided when the virtual table is created:

```swift
// CREATE VIRTUAL TABLE documents USING fts5(
//     tokenize='custom',
//     content
// )
try db.create(virtualTable: "documents", using: FTS5()) { t in
    // Wraps the default unicode61
    t.tokenizer = MyTokenizer.tokenizerDescriptor()
    t.column("content")
}

// CREATE VIRTUAL TABLE documents USING fts5(
//     tokenize='custom ascii'
//     content
// )
try db.create(virtualTable: "documents", using: FTS5()) { t in
    // Wraps ascii
    let ascii = FTS5TokenizerDescriptor.ascii()
    t.tokenizer = MyTokenizer.tokenizerDescriptor(arguments: ascii.components)
    t.column("content")
}
```


## Example: Synonyms

**FTS5 lets tokenizers produce synonyms**, so that, for example, "first" can match "1st".

The topic of synonyms is documented at https://www.sqlite.org/fts5.html#synonym_support, which describes several methods. You should carefully read this documentation, and pick the method you prefer.

In the example below, we'll pick method (3), and implement a tokenizer that adds multiple synonyms for a single term to the FTS index. Using this method, when tokenizing document text, the tokenizer provides multiple synonyms for each token. So that when a document such as "I won first place" is tokenized, entries are added to the FTS index for "i", "won", "first", "1st" and "place".

We'll also take care of the SQLite advice:

> When using methods (2) or (3), it is important that the tokenizer only provide synonyms when tokenizing document text or query text, not both. Doing so will not cause any errors, but is inefficient.

```swift
final class SynonymsTokenizer : FTS5WrapperTokenizer {
    static let name = "synonyms"
    let wrappedTokenizer: FTS5Tokenizer
    let synonyms: [Set<String>] = [["first", "1st"]]
    
    init(db: Database, arguments: [String]) throws {
        wrappedTokenizer = try db.makeTokenizer(.unicode61())
    }
    
    func synonyms(for token: String) -> Set<String>? {
        return synonyms.first { $0.contains(token) }
    }
    
    func accept(token: String, flags: FTS5TokenFlags, for tokenization: FTS5Tokenization, tokenCallback: FTS5WrapperTokenCallback) throws {
        if tokenization.contains(.query) {
            // Don't look for synonyms when tokenizing queries
            try tokenCallback(token, flags)
            return
        }
        
        guard let synonyms = synonyms(for: token) else {
            // Token has no synonym
            try tokenCallback(token, flags)
            return
        }
        
        for (index, synonym) in synonyms.enumerated() {
            // Notify each synonym, and set the colocated flag for all but the first
            let synonymFlags = (index == 0) ? flags : flags.union(.colocated)
            try tokenCallback(synonym, synonymFlags)
        }
    }
}

```


## Example: Latin Script

Languages that use the [latin script](https://en.wikipedia.org/wiki/Latin_script) offer a rich set of typographical, historical, and local features such as diacritics, ligatures, and dotless I: Großmann, ﬁdélité (with the ligature "fi" U+FB01), Diyarbakır.

Full-text search in such a corpus often needs input tolerance, so that "encyclopaedia" can match "Encyclopædia", "Grossmann", "Großmann", and "Jerome", "Jérôme".

German has something specific in that both "Mueller" and "Muller" should match "Müller", when "Bauer" should not match "Baur" (only "ü" accepts both "u" and "ue"). A pull request that adds a chapter about German will be welcome.

A custom FTS5 tokenizer lets you provide fuzzy latin matching: after "Grossmann", "Großmann", and "GROSSMANN" have all been turned into "grossmann", they will all match together.

We'll wrap the built-in [unicode61](https://www.sqlite.org/fts5.html#unicode61_tokenizer) tokenizer (the one that knows how to split text on spaces and punctuations), and transform its tokens into their bare lowercase ascii form.

The tokenizer wrapping is provided by the [FTS5WrapperTokenizer](#fts5wrappertokenizer) protocol. The string transformation is provided by the [String.applyingTransform](https://developer.apple.com/reference/swift/string/1643133-applyingtransform) method:

```swift
final class LatinAsciiTokenizer : FTS5WrapperTokenizer {
    static let name = "latinascii"
    let wrappedTokenizer: FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        wrappedTokenizer = try db.makeTokenizer(.unicode61())
    }
    
    func accept(token: String, flags: FTS5TokenFlags, for tokenization: FTS5Tokenization, tokenCallback: FTS5WrapperTokenCallback) throws {
        if let token = token.applyingTransform(StringTransform("Latin-ASCII; Lower"), reverse: false) {
            try tokenCallback(token, flags)
        }
    }
}
```

> :point_up: **Note**: String.applyingTransform is not available before iOS 9.0 and macOS 10.11. Use the Core Foundation function [CFStringTransform](https://developer.apple.com/reference/corefoundation/1542411-cfstringtransform) instead.

Remember to register LatinAsciiTokenizer before using it:

```swift
dbQueue.add(tokenizer: LatinAsciiTokenizer.self) // or dbPool.add

dbQueue.inDatabase { db in
    try db.create(virtualTable: "documents", using: FTS5()) { t in
        t.tokenizer = LatinAsciiTokenizer.tokenizerDescriptor()
        t.column("authors")
        t.column("title")
        t.column("body")
    }
}
```
