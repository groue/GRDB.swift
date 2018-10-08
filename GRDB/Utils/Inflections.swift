//
//  Inflections.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/10/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

import Foundation

extension String {
    var uppercasingFirstCharacter: String {
        guard let first = first else {
            return self
        }
        return String(first).uppercased() + dropFirst()
    }
}
