@import Foundation;

//! Project version number for GRDB.
FOUNDATION_EXPORT double GRDB_VersionNumber;

//! Project version string for GRDB.
FOUNDATION_EXPORT const unsigned char GRDB_VersionString[];

#define SQLITE_HAS_CODEC
#import <GRDBCipher/GRDBCipher-Bridging.h>
#import <GRDBCipher/sqlite3.h>
