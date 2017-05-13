@import Foundation;

//! Project version number for GRDB.
FOUNDATION_EXPORT double GRDB_VersionNumber;

//! Project version string for GRDB.
FOUNDATION_EXPORT const unsigned char GRDB_VersionString[];

#import <GRDB/GRDB-Bridging.h>

#if SQLITE_HAS_CODEC
    #import <SQLCipher/sqlite3.h>
#else
    #import <GRDB/sqlite3.h>
#endif
