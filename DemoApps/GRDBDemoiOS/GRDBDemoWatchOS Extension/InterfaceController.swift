//
//  InterfaceController.swift
//  GRDBDemoWatchOS Extension
//
//  Created by Gwendal Roué on 03/04/2017.
//  Copyright © 2017 Gwendal Roué. All rights reserved.
//

import WatchKit
import Foundation
import GRDB

class InterfaceController: WKInterfaceController {
    
    @IBOutlet var versionLabel: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        let sqliteVersion = String(cString: sqlite3_libversion(), encoding: .utf8)
        versionLabel.setText(sqliteVersion)
    }
}
