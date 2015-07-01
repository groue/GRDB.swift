//
//  DatabaseConfiguration.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public struct DatabaseConfiguration {
    public let foreignKeysEnabled: Bool
    public let verbose: Bool
    
    public init(foreignKeysEnabled: Bool = true, verbose: Bool = false) {
        self.foreignKeysEnabled = foreignKeysEnabled
        self.verbose = verbose
    }
}
