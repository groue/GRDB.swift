@import Foundation;

//! Project version number for GRDB.
FOUNDATION_EXPORT double GRDB_VersionNumber;

//! Project version string for GRDB.
FOUNDATION_EXPORT const unsigned char GRDB_VersionString[];

#import <GRDB/GRDB-Bridging.h>
#define SQLITE_HAS_CODEC
#import <GRDB/sqlite3.h>
