//
//  UpdateStatement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public class UpdateStatement : Statement {
    
    public func executeUpdate() throws {
        let code = sqlite3_step(cStatement)
        switch code {
        case SQLITE_DONE:
            // the statement has finished executing successfully
            break
        default:
            try Error.checkCResultCode(code, cConnection: cConnection)
        }
    }
}
