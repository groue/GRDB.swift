Custom FTS5 Tokenizers
======================

**[FTS5](https://www.sqlite.org/fts5.html) is an extensible full-text search engine.**

GRDB lets you define your own custom FST5 tokenizers, and extend SQLite built-in tokenizers. Possible use cases are:

- Have "fi" match the ligature "&#xfb01;" (U+FB01)
- Have "first" match "1st"
- Have "Encyclopaedia" match "Encyclopædia"
- Have "Mueller" match "Müller", and "Grossman" match "Großmann"
- Prevent "the" and other stop words from matching any document

## The Tokenizer Protocols

- `FTS5Tokenizer`: the protocol for all FTS5 tokenizers, including built-in tokenizers such as `ascii`, `unicode61`, and `porter`.

    - `FTS5CustomTokenizer`: the low-level protocol for all custom tokenizers.
    
        - `FTS5WrapperTokenizer`: the high-level protocol for custom tokenizers that wrap an existing tokenizer, and post-processes its tokens.

