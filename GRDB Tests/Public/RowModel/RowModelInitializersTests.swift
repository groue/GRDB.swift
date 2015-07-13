//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import XCTest
import GRDB

// Tests about how minimal can class go regarding their initializers

// What happens for a class without property, without any initializer?
class EmptyRowModelWithoutInitializer : RowModel {
    // nothing is required
}

// What happens if we add a mutable property, still without any initializer?
// A compiler error: class 'RowModelWithoutInitializer' has no initializers
//
//    class RowModelWithoutInitializer : RowModel {
//        let name: String?
//    }

// What happens with a mutable property, and init(row: Row)?
class RowModelWithMutablePropertyAndRowInitializer : RowModel {
    var name: String?
    
    required init(row: Row) {
        super.init(row: row)        // super.init(row: row) is required
        self.name = "toto"          // property can be set before or after super.init
    }
}

// What happens with a mutable property, and init()?
class RowModelWithMutablePropertyAndEmptyInitializer : RowModel {
    var name: String?
    
    override init() {
        super.init()                // super.init() is required
        self.name = "toto"          // property can be set before or after super.init
    }
    
    required init(row: Row) {       // init(row: row) is required
        super.init(row: row)        // super.init(row: row) is required
    }
}

// What happens with a mutable property, and a custom initializer()?
class RowModelWithMutablePropertyAndCustomInitializer : RowModel {
    var name: String?
    
    init(name: String? = nil) {
        self.name = name
        super.init()                // super.init() is required
    }

    required init(row: Row) {       // init(row: row) is required
        super.init(row: row)        // super.init(row: row) is required
    }
}

// What happens with an immutable property?
class RowModelWithImmutableProperty : RowModel {
    let initializedFromRow: Bool
    
    required init(row: Row) {       // An initializer is required, and the minimum is init(row: row)
        initializedFromRow = true   // property must bet set before super.init(row: row)
        super.init(row: row)        // super.init(row: row) is required
    }
}

// What happens with an immutable property and init()?
class RowModelWithPedigree : RowModel {
    let initializedFromRow: Bool
    
    override init() {
        initializedFromRow = false  // property must bet set before super.init(row: row)
        super.init()                // super.init() is required
    }
    
    required init(row: Row) {       // An initializer is required, and the minimum is init(row: row)
        initializedFromRow = true   // property must bet set before super.init(row: row)
        super.init(row: row)        // super.init(row: row) is required
    }
}

// What happens with an immutable property and a custom initializer()?
class RowModelWithImmutablePropertyAndCustomInitializer : RowModel {
    let initializedFromRow: Bool
    
    init(name: String? = nil) {
        initializedFromRow = false  // property must bet set before super.init(row: row)
        super.init()                // super.init() is required
    }
    
    required init(row: Row) {       // An initializer is required, and the minimum is init(row: row)
        initializedFromRow = true   // property must bet set before super.init(row: row)
        super.init(row: row)        // super.init(row: row) is required
    }
}

class RowModelInitializersTests : RowModelTestCase {
    
    func testFetchedRowModelAreInitializedFromRow() {
        
        // Here we test that RowModel.init(row: Row) can be overriden independently from RowModel.init().
        // People must be able to perform some initialization work when fetching row models from the database.
        
        XCTAssertFalse(RowModelWithPedigree().initializedFromRow)
        
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE pedigrees (foo INTEGER)")
                try db.execute("INSERT INTO pedigrees (foo) VALUES (NULL)")
                
                let pedigree = db.fetchOne(RowModelWithPedigree.self, "SELECT * FROM pedigrees")!
                XCTAssertTrue(pedigree.initializedFromRow)  // very important
            }
        }
    }
}
