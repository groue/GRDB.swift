//
//  Configuration.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public struct Configuration {
    public typealias TraceFunction = (String) -> Void
    
    public var foreignKeysEnabled: Bool
    public var readonly: Bool
    public var trace: TraceFunction?
    
    public init(foreignKeysEnabled: Bool = true, readonly: Bool = false, trace: TraceFunction? = nil) {
        self.foreignKeysEnabled = foreignKeysEnabled
        self.readonly = readonly
        self.trace = trace
    }
    
    var sqliteOpenFlags: Int32 {
        // See https://www.sqlite.org/c3ref/open.html
        return readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
    }
}
