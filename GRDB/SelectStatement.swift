//
//  SelectStatement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public class SelectStatement : Statement {
    public lazy var columnCount: Int = Int(sqlite3_column_count(self.cStatement))
    
    private var rowGenerator: AnyGenerator<Row> {
        try! reset()
        var logFirstStep = database.configuration.verbose
        return anyGenerator { () -> Row? in
            if logFirstStep {
                NSLog("%@", self.sql)
                logFirstStep = false
            }
            let code = sqlite3_step(self.cStatement)
            switch code {
            case SQLITE_DONE:
                return nil
            case SQLITE_ROW:
                return Row(statement: self)
            default:
                try! Error.checkCResultCode(code, cConnection: self.database.cConnection)
                return nil
            }
        }
    }
    
    private func valueGenerator<T: DBValue>(type: T.Type) -> AnyGenerator<T?> {
        let rowGenerator = self.rowGenerator
        return anyGenerator { () -> T?? in
            if let row = rowGenerator.next() {
                return Optional.Some(row.valueAtIndex(0, type: type))
            } else {
                return nil
            }
        }
    }
    
    // TODO: Document the reset performed on each generation
    public func fetchRows() -> AnySequence<Row> {
        return AnySequence {
            return self.rowGenerator
        }
    }
    
    public func fetchValues<T: DBValue>(type: T.Type) -> AnySequence<T?> {
        return AnySequence {
            return self.valueGenerator(type)
        }
    }
}
