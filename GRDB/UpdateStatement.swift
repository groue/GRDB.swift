//
//  UpdateStatement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public final class UpdateStatement : Statement {
    
    public func execute() throws {
        if database.configuration.verbose {
            NSLog("%@", sql)
        }
        let code = sqlite3_step(sqliteStatement)
        switch code {
        case SQLITE_DONE:
            // the statement has finished executing successfully
            break
        default:
            try SQLiteError.checkCResultCode(code, sqliteConnection: database.sqliteConnection, sql: sql)
        }
    }
}
