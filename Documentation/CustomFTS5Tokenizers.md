Custom FTS5 Tokenizers
======================

**[FTS5](https://www.sqlite.org/fts5.html) is an extensible full-text search engine.**

GRDB lets you define your own custom FST5 tokenizers, and extend SQLite built-in tokenizers. Possible use cases are:

- Have "fi" match the ligature "&#xfb01;" (U+FB01)
- Have "first" match "1st"
- Have "Encyclopaedia" match "Encyclopædia"
- Have "Mueller" match "Müller", and "Grossman" match "Großmann"
- Have "romaji" match "ローマ字"
- Have "pinyin" match "拼音"
- Prevent "the" and other stop words from matching any document


## The Tokenizer Protocols

- [FTS5Tokenizer](#fts5tokenizer): the protocol for all FTS5 tokenizers, including built-in tokenizers such as `ascii`, `unicode61`, and `porter`.
    
    - [FTS5CustomTokenizer](#fts5customtokenizer): the low-level protocol for all custom tokenizers, close to the FTS5 metal.
    
        - [FTS5WrapperTokenizer](#fts5wrappertokenizer): the high-level protocol for custom tokenizers that post-processes the tokens produced by another FTS5Tokenizer.


## Using A Custom Tokenizer

Once you have a type that implements FTS5CustomTokenizer or FTS5WrapperTokenizer, you can create full-text tables that use it:

```swift
class MyTokenizer : FTS5CustomTokenizer { ... }

try db.create(virtualTable: "documents", using: FTS5()) { t in
    t.tokenizer = MyTokenizer.tokenizerDescriptor()
    t.column("authors")
    t.column("title")
    t.column("body")
}
```

And then the full-text table can be fed and queried in a regular way:

```swift
try Document(...).insert(db)
let documents = Document.matching(...).fetchAll(db)
```

## FTS5Tokenizer


## FTS5CustomTokenizer


## FTS5WrapperTokenizer

