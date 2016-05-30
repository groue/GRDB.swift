@import Foundation;

//! Project version number for GRDB.
FOUNDATION_EXPORT double GRDB_VersionNumber;

//! Project version string for GRDB.
FOUNDATION_EXPORT const unsigned char GRDB_VersionString[];

// INSERT ANY ADDITIONAL SQLITE DEFINES HERE
#define SQLITE_ENABLE_PREUPDATE_HOOK
// -----------------------------------------
#import <GRDBCustomSQLite/GRDBCustomSQLite-Bridging.h>
#import <GRDBCustomSQLite/sqlite3.h>
