//
//  UpdateStatement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public class UpdateStatement : Statement {
    public lazy var lastInsertedRowID: Int64 = sqlite3_last_insert_rowid(self.cStatement)
    
    public func execute() throws {
        NSLog("%@", sql)
        let code = sqlite3_step(cStatement)
        switch code {
        case SQLITE_DONE:
            // the statement has finished executing successfully
            break
        default:
            try Error.checkCResultCode(code, cConnection: database.cConnection)
        }
    }
}
