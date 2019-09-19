#ifndef grdb_config_h
#define grdb_config_h

#if defined(COCOAPODS)
    #if defined(GRDBCIPHER)
        #include <SQLCipher/sqlite3.h>
    #else
        #include <sqlite3.h>
    #endif
#else
    #if defined(GRDBCUSTOMSQLITE)
        #include <GRDBCustom/sqlite3.h>
    #else
        #include <sqlite3.h>
    #endif
#endif

typedef void(*errorLogCallback)(void *pArg, int iErrCode, const char *zMsg);

// Wrapper around sqlite3_config(SQLITE_CONFIG_LOG, ...) which is a variadic
// function that can't be used from Swift.
static inline void registerErrorLogCallback(errorLogCallback callback) {
    sqlite3_config(SQLITE_CONFIG_LOG, callback, 0);
}

// MARK: - Snapshots

typedef struct sqlite3_snapshot {
  unsigned char hidden[48];
} sqlite3_snapshot;
SQLITE_API SQLITE_EXPERIMENTAL int sqlite3_snapshot_get(
  sqlite3 *db,
  const char *zSchema,
  sqlite3_snapshot **ppSnapshot
);
SQLITE_API SQLITE_EXPERIMENTAL int sqlite3_snapshot_open(
  sqlite3 *db,
  const char *zSchema,
  sqlite3_snapshot *pSnapshot
);
SQLITE_API SQLITE_EXPERIMENTAL void sqlite3_snapshot_free(sqlite3_snapshot*);
SQLITE_API SQLITE_EXPERIMENTAL int sqlite3_snapshot_cmp(
  sqlite3_snapshot *p1,
  sqlite3_snapshot *p2
);
SQLITE_API SQLITE_EXPERIMENTAL int sqlite3_snapshot_recover(sqlite3 *db, const char *zDb);

#endif /* grdb_config_h */
