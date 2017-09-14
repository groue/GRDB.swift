@import Foundation;

//! Project version number for GRDB.
FOUNDATION_EXPORT double GRDB_VersionNumber;

//! Project version string for GRDB.
FOUNDATION_EXPORT const unsigned char GRDB_VersionString[];

#ifndef SQLITE_HAS_CODEC
#define SQLITE_HAS_CODEC
#endif

#import <GRDBCipher/GRDBCipher-Bridging.h>
#ifdef COCOAPODS
    #import <SQLCipher/sqlite3.h>
#else
    #import <GRDBCipher/sqlite3.h>
#endif
