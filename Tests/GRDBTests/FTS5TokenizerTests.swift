#if SQLITE_ENABLE_FTS5
import XCTest
import GRDB

class FTS5TokenizerTests: GRDBTestCase {
    
    private func match(_ db: Database, _ content: String, _ query: String) -> Bool {
        try! db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: [content])
        defer {
            try! db.execute(sql: "DELETE FROM documents")
        }
        return try! Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: [query])! > 0
    }
    
    func testAsciiTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .ascii()
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertFalse(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertFalse(match(db, "jérôme", "JÉRÔME"))
        }
    }

    func testAsciiTokenizerSeparators() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .ascii(separators: ["X"])
                t.column("content")
            }

            XCTAssertTrue(match(db, "abcXdef", "abcXdef"))
            XCTAssertFalse(match(db, "abcXdef", "defXabc")) // likely a bug in FTS5. FTS3 handles that well.
            XCTAssertTrue(match(db, "abcXdef", "abc"))
            XCTAssertTrue(match(db, "abcXdef", "def"))
        }
    }

    func testAsciiTokenizerTokenCharacters() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .ascii(tokenCharacters: Set(".-"))
                t.column("content")
            }

            XCTAssertTrue(match(db, "2016-10-04.txt", "\"2016-10-04.txt\""))
            XCTAssertFalse(match(db, "2016-10-04.txt", "2016"))
            XCTAssertFalse(match(db, "2016-10-04.txt", "txt"))
        }
    }

    func testDefaultPorterTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .porter()
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertTrue(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertTrue(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
        }
    }

    func testPorterOnAsciiTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .porter(wrapping: .ascii())
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertTrue(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertFalse(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertFalse(match(db, "jérôme", "JÉRÔME"))
        }
    }

    func testPorterOnUnicode61Tokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertTrue(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertTrue(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
        }
    }

    func testUnicode61Tokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61()
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertTrue(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
        }
    }

    func testUnicode61TokenizerDiacriticsKeep() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(diacritics: .keep)
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertFalse(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
        }
    }
    
    #if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
    func testUnicode61TokenizerDiacriticsRemove() throws {
        guard Database.sqliteLibVersionNumber >= 3027000 else {
            throw XCTSkip("remove_diacritics=2 is not available")
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertTrue(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
        }
    }
    #else
    func testUnicode61TokenizerDiacriticsRemove() throws {
        guard #available(iOS 14, macOS 10.16, tvOS 14, *) else {
            throw XCTSkip("remove_diacritics=2 is not available")
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertTrue(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
        }
    }
    #endif

    func testUnicode61TokenizerCategories() throws {
        // Prevent SQLCipher failures.
        // Categories are not mentioned in the SQLite release notes.
        // They were introduced on 2018-07-13 in https://sqlite.org/src/info/80d2b9e635e3100f
        // Next version is 3.25.0.
        // So we assume support for categories was introduced in SQLite 3.25.0.
        guard Database.sqliteLibVersionNumber >= 3025000 else {
            throw XCTSkip("FTS5 unicode61 tokenizer categories are not available")
        }
        
        // Default categories
        try makeDatabaseQueue().inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.column("content")
            }
            
            XCTAssertTrue(match(db, "ABC", "abc"))
            XCTAssertFalse(match(db, "👍", "👍"))
            XCTAssertTrue(match(db, "👁‍🗨", "🗨"))
            XCTAssertFalse(match(db, "🔎🐠", "🐠"))
            XCTAssertFalse(match(db, "🔎🐠", "🔎🐠"))
        }
        
        // Default categories plus symbols
        try makeDatabaseQueue().inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(categories: "L* N* Co S*")
                t.column("content")
            }
            
            XCTAssertTrue(match(db, "ABC", "abc"))
            XCTAssertTrue(match(db, "👍", "👍"))
            XCTAssertTrue(match(db, "👁‍🗨", "🗨"))
            XCTAssertFalse(match(db, "🔎🐠", "🐠"))
            XCTAssertTrue(match(db, "🔎🐠", "🔎🐠"))
        }
        
        // Only lowercase letters
        try makeDatabaseQueue().inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(categories: "Ll")
                t.column("content")
            }
            
            XCTAssertTrue(match(db, "ABCdef g H", "ABCdef"))
            XCTAssertTrue(match(db, "ABCdef g H", "def"))
            XCTAssertTrue(match(db, "ABCdef g H", "g"))
            XCTAssertFalse(match(db, "ABCdef g H", "h"))
        }
    }

    func testUnicode61TokenizerSeparators() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(separators: ["X"])
                t.column("content")
            }
            
            XCTAssertTrue(match(db, "abcXdef", "abcXdef"))
            XCTAssertFalse(match(db, "abcXdef", "defXabc")) // likely a bug in FTS5. FTS3 handles that well.
            XCTAssertTrue(match(db, "abcXdef", "abc"))
            XCTAssertTrue(match(db, "abcXdef", "def"))
        }
    }

    func testUnicode61TokenizerTokenCharacters() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(tokenCharacters: Set(".-"))
                t.column("content")
            }
            
            XCTAssertTrue(match(db, "2016-10-04.txt", "\"2016-10-04.txt\""))
            XCTAssertFalse(match(db, "2016-10-04.txt", "2016"))
            XCTAssertFalse(match(db, "2016-10-04.txt", "txt"))
        }
    }
    
    func testTrigramTokenizer() throws {
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard sqlite3_libversion_number() >= 3034000 else {
            throw XCTSkip("FTS5 trigram tokenizer is not available")
        }
        #else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("FTS5 trigram tokenizer is not available")
        }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .trigram()
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertFalse(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
            
            // substring match
            XCTAssertTrue(match(db, "sequence", "que"))
        }
    }
    
    func testTrigramTokenizerCaseSensitive() throws {
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard sqlite3_libversion_number() >= 3034000 else {
            throw XCTSkip("FTS5 trigram tokenizer is not available")
        }
        #else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("FTS5 trigram tokenizer is not available")
        }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .trigram(caseSensitive: true)
                t.column("content")
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertFalse(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertFalse(match(db, "jérôme", "JÉRÔME"))
            
            // substring match
            XCTAssertTrue(match(db, "sequence", "que"))
            
            // substring match with too short query
            XCTAssertFalse(match(db, "sequence", "qu"))
        }
    }
    
    func testTrigramTokenizerDiacriticsRemove() throws {
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard sqlite3_libversion_number() >= 3045000 else {
            throw XCTSkip("FTS5 trigram tokenizer remove_diacritics is not available")
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .trigram(removeDiacritics: .remove)
                    t.column("content")
                }
            } catch {
                print(error)
                throw error
            }
            
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertTrue(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
            
            // substring match
            XCTAssertTrue(match(db, "sequence", "que"))
            
            // substring match with too short query
            XCTAssertFalse(match(db, "sequence", "qu"))
        }
        #else
        throw XCTSkip("FTS5 trigram tokenizer remove_diacritics is not available")
        #endif
    }
    
    func testTokenize() throws {
        try makeDatabaseQueue().inDatabase { db in
            let ascii = try db.makeTokenizer(.ascii())
            let porter = try db.makeTokenizer(.porter())
            let unicode61 = try db.makeTokenizer(.unicode61())
            let unicode61WithDiacritics = try db.makeTokenizer(.unicode61(diacritics: .keep))
            
            // Empty query
            try XCTAssertEqual(ascii.tokenize(query: "").map(\.token), [])
            try XCTAssertEqual(porter.tokenize(query: "").map(\.token), [])
            try XCTAssertEqual(unicode61.tokenize(query: "").map(\.token), [])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "").map(\.token), [])
            
            try XCTAssertEqual(ascii.tokenize(query: "?!").map(\.token), [])
            try XCTAssertEqual(porter.tokenize(query: "?!").map(\.token), [])
            try XCTAssertEqual(unicode61.tokenize(query: "?!").map(\.token), [])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "?!").map(\.token), [])
            
            // Token queries
            try XCTAssertEqual(ascii.tokenize(query: "Moby").map(\.token), ["moby"])
            try XCTAssertEqual(porter.tokenize(query: "Moby").map(\.token), ["mobi"])
            try XCTAssertEqual(unicode61.tokenize(query: "Moby").map(\.token), ["moby"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "Moby").map(\.token), ["moby"])
            
            try XCTAssertEqual(ascii.tokenize(query: "écarlates").map(\.token), ["écarlates"])
            try XCTAssertEqual(porter.tokenize(query: "écarlates").map(\.token), ["ecarl"])
            try XCTAssertEqual(unicode61.tokenize(query: "écarlates").map(\.token), ["ecarlates"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "écarlates").map(\.token), ["écarlates"])
            
            try XCTAssertEqual(ascii.tokenize(query: "fooéı👨👨🏿🇫🇷🇨🇮").map(\.token), ["fooéı👨👨🏿🇫🇷🇨🇮"])
            try XCTAssertEqual(porter.tokenize(query: "fooéı👨👨🏿🇫🇷🇨🇮").map(\.token), ["fooeı", "🏿"])
            try XCTAssertEqual(unicode61.tokenize(query: "fooéı👨👨🏿🇫🇷🇨🇮").map(\.token), ["fooeı", "🏿"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "fooéı👨👨🏿🇫🇷🇨🇮").map(\.token), ["fooéı", "🏿"])
            
            try XCTAssertEqual(ascii.tokenize(query: "SQLite database").map(\.token), ["sqlite", "database"])
            try XCTAssertEqual(porter.tokenize(query: "SQLite database").map(\.token), ["sqlite", "databas"])
            try XCTAssertEqual(unicode61.tokenize(query: "SQLite database").map(\.token), ["sqlite", "database"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "SQLite database").map(\.token), ["sqlite", "database"])
            
            try XCTAssertEqual(ascii.tokenize(query: "Édouard Manet").map(\.token), ["Édouard", "manet"])
            try XCTAssertEqual(porter.tokenize(query: "Édouard Manet").map(\.token), ["edouard", "manet"])
            try XCTAssertEqual(unicode61.tokenize(query: "Édouard Manet").map(\.token), ["edouard", "manet"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "Édouard Manet").map(\.token), ["édouard", "manet"])
            
            // Prefix queries
            try XCTAssertEqual(ascii.tokenize(query: "*").map(\.token), [])
            try XCTAssertEqual(porter.tokenize(query: "*").map(\.token), [])
            try XCTAssertEqual(unicode61.tokenize(query: "*").map(\.token), [])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "*").map(\.token), [])
            
            try XCTAssertEqual(ascii.tokenize(query: "Robin*").map(\.token), ["robin"])
            try XCTAssertEqual(porter.tokenize(query: "Robin*").map(\.token), ["robin"])
            try XCTAssertEqual(unicode61.tokenize(query: "Robin*").map(\.token), ["robin"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "Robin*").map(\.token), ["robin"])
            
            // Phrase queries
            try XCTAssertEqual(ascii.tokenize(query: "\"foulent muscles\"").map(\.token), ["foulent", "muscles"])
            try XCTAssertEqual(porter.tokenize(query: "\"foulent muscles\"").map(\.token), ["foulent", "muscl"])
            try XCTAssertEqual(unicode61.tokenize(query: "\"foulent muscles\"").map(\.token), ["foulent", "muscles"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "\"foulent muscles\"").map(\.token), ["foulent", "muscles"])
            
            try XCTAssertEqual(ascii.tokenize(query: "\"Kim Stan* Robin*\"").map(\.token), ["kim", "stan", "robin"])
            try XCTAssertEqual(porter.tokenize(query: "\"Kim Stan* Robin*\"").map(\.token), ["kim", "stan", "robin"])
            try XCTAssertEqual(unicode61.tokenize(query: "\"Kim Stan* Robin*\"").map(\.token), ["kim", "stan", "robin"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "\"Kim Stan* Robin*\"").map(\.token), ["kim", "stan", "robin"])
            
            // Logical queries
            try XCTAssertEqual(ascii.tokenize(query: "years AND months").map(\.token), ["years", "and", "months"])
            try XCTAssertEqual(porter.tokenize(query: "years AND months").map(\.token), ["year", "and", "month"])
            try XCTAssertEqual(unicode61.tokenize(query: "years AND months").map(\.token), ["years", "and", "months"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "years AND months").map(\.token), ["years", "and", "months"])
            
            // column queries
            try XCTAssertEqual(ascii.tokenize(query: "title:brest").map(\.token), ["title", "brest"])
            try XCTAssertEqual(porter.tokenize(query: "title:brest").map(\.token), ["titl", "brest"])
            try XCTAssertEqual(unicode61.tokenize(query: "title:brest").map(\.token), ["title", "brest"])
            try XCTAssertEqual(unicode61WithDiacritics.tokenize(query: "title:brest").map(\.token), ["title", "brest"])
        }
    }
    
    func testTokenizeTrigram() throws {
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard sqlite3_libversion_number() >= 3034000 else {
            throw XCTSkip("FTS5 trigram tokenizer is not available")
        }
        #else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("FTS5 trigram tokenizer is not available")
        }
        #endif
        
        try makeDatabaseQueue().inDatabase { db in
            let trigram = try db.makeTokenizer(.trigram())
            
            // Empty query
            try XCTAssertEqual(trigram.tokenize(query: "").map(\.token), [])
            try XCTAssertEqual(trigram.tokenize(query: "?!").map(\.token), [])
            
            // Token queries
            try XCTAssertEqual(trigram.tokenize(query: "Moby").map(\.token), ["mob", "oby"])
            try XCTAssertEqual(trigram.tokenize(query: "écarlates").map(\.token), ["éca", "car", "arl", "rla", "lat", "ate", "tes"])
            try XCTAssertEqual(trigram.tokenize(query: "fooéı👨👨🏿🇫🇷🇨🇮").map(\.token), ["foo", "ooé", "oéı", "éı👨", "ı👨👨", "👨👨🏿", "👨🏿🇫", "\u{0001F3FF}🇫🇷", "🇫🇷🇨", "🇷🇨🇮"])
            try XCTAssertEqual(trigram.tokenize(query: "SQLite database").map(\.token), ["sql", "qli", "lit", "ite", "te ", "e d", " da", "dat", "ata", "tab", "aba", "bas", "ase"])
            try XCTAssertEqual(trigram.tokenize(query: "Édouard Manet").map(\.token), ["édo", "dou", "oua", "uar", "ard", "rd ", "d m", " ma", "man", "ane", "net"])
            
            // Prefix queries
            try XCTAssertEqual(trigram.tokenize(query: "*").map(\.token), [])
            try XCTAssertEqual(trigram.tokenize(query: "Robin*").map(\.token), ["rob", "obi", "bin", "in*"])
            
            // Phrase queries
            try XCTAssertEqual(trigram.tokenize(query: "\"foulent muscles\"").map(\.token), ["\"fo", "fou", "oul", "ule", "len", "ent", "nt ", "t m", " mu", "mus", "usc", "scl", "cle", "les", "es\""])
            try XCTAssertEqual(trigram.tokenize(query: "\"Kim Stan* Robin*\"").map(\.token), ["\"ki", "kim", "im ", "m s", " st", "sta", "tan", "an*", "n* ", "* r", " ro", "rob", "obi", "bin", "in*", "n*\""])
            
            // Logical queries
            try XCTAssertEqual(trigram.tokenize(query: "years AND months").map(\.token), ["yea", "ear", "ars", "rs ", "s a", " an", "and", "nd ", "d m", " mo", "mon", "ont", "nth", "ths"])
            
            // column queries
            try XCTAssertEqual(trigram.tokenize(query: "title:brest").map(\.token), ["tit", "itl", "tle", "le:", "e:b", ":br", "bre", "res", "est"])
        }
    }
    
    func testTokenize_Unicode61TokenizerCategories() throws {
        // Prevent SQLCipher failures.
        // Categories are not mentioned in the SQLite release notes.
        // They were introduced on 2018-07-13 in https://sqlite.org/src/info/80d2b9e635e3100f
        // Next version is 3.25.0.
        // So we assume support for categories was introduced in SQLite 3.25.0.
        guard Database.sqliteLibVersionNumber >= 3025000 else {
            throw XCTSkip("FTS5 unicode61 tokenizer categories are not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            let unicode61OnlyLowercaseLetters = try db.makeTokenizer(.unicode61(categories: "Ll"))
            let unicode61WithSymbols = try db.makeTokenizer(.unicode61(categories: "L* N* Co S*"))
            
            // Empty query
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "").map(\.token), [])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "").map(\.token), [])
            
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "?!").map(\.token), [])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "?!").map(\.token), [])
            
            // Token queries
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "Moby").map(\.token), ["oby"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "Moby").map(\.token), ["moby"])
            
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "écarlates").map(\.token), ["ecarlates"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "écarlates").map(\.token), ["ecarlates"])
            
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "fooéı👨👨🏿🇫🇷🇨🇮").map(\.token), ["fooeı", "🏿"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "fooéı👨👨🏿🇫🇷🇨🇮").map(\.token), ["fooeı👨👨🏿🇫🇷🇨🇮"])
            
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "SQLite database").map(\.token), ["ite", "database"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "SQLite database").map(\.token), ["sqlite", "database"])
            
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "Édouard Manet").map(\.token), ["douard", "anet"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "Édouard Manet").map(\.token), ["edouard", "manet"])
            
            // Prefix queries
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "*").map(\.token), [])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "*").map(\.token), [])
            
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "Robin*").map(\.token), ["obin"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "Robin*").map(\.token), ["robin"])
            
            // Phrase queries
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "\"foulent muscles\"").map(\.token), ["foulent", "muscles"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "\"foulent muscles\"").map(\.token), ["foulent", "muscles"])
            
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "\"Kim Stan* Robin*\"").map(\.token), ["im", "tan", "obin"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "\"Kim Stan* Robin*\"").map(\.token), ["kim", "stan", "robin"])
            
            // Logical queries
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "years AND months").map(\.token), ["years", "months"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "years AND months").map(\.token), ["years", "and", "months"])
            
            // column queries
            try XCTAssertEqual(unicode61OnlyLowercaseLetters.tokenize(query: "title:brest").map(\.token), ["title", "brest"])
            try XCTAssertEqual(unicode61WithSymbols.tokenize(query: "title:brest").map(\.token), ["title", "brest"])
        }
    }
}
#endif
