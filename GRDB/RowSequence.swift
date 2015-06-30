//
//  SequenceStatement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public class RowSequence : Statement, SequenceType {
    private var _rowGenerator: RowGenerator?
    
    public func generate() -> RowGenerator {
        if let _rowGenerator = _rowGenerator {
            return _rowGenerator
        }
        _rowGenerator = RowGenerator(cConnection: cConnection, cStatement: cStatement)
        return _rowGenerator!
    }
    
    override public func reset() {
        super.reset()
        _rowGenerator = nil
    }
    
    public class RowGenerator : GeneratorType {
        let cStatement: CStatement
        let cConnection: CConnection
        
        init(cConnection: CConnection, cStatement: CStatement) {
            self.cConnection = cConnection
            self.cStatement = cStatement
        }
        
        public func next() -> Row? {
            let code = sqlite3_step(cStatement)
            switch code {
            case SQLITE_DONE:
                // the statement has finished executing successfully
                return nil
            case SQLITE_ROW:
                // each time a new row of data is ready for processing by the caller.
                return Row(cStatement: cStatement)
            default:
                try! Error.checkCResultCode(code, cConnection: cConnection)
                return nil
            }
        }
    }
}
