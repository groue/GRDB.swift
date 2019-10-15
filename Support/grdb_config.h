#ifndef grdb_config_h
#define grdb_config_h

#if defined(COCOAPODS)
    #if defined(GRDBCIPHER)
        #include <SQLCipher/sqlite3.h>
    #else
        #include <sqlite3.h>
    #endif
#else
    #if !defined(GRDBCUSTOMSQLITE)
        #include <sqlite3.h>
    #endif
#endif

typedef void(*errorLogCallback)(void *pArg, int iErrCode, const char *zMsg);

// Wrapper around sqlite3_config(SQLITE_CONFIG_LOG, ...) which is a variadic
// function that can't be used from Swift.
static inline void registerErrorLogCallback(errorLogCallback callback) {
    sqlite3_config(SQLITE_CONFIG_LOG, callback, 0);
}

// Expose APIs that are missing from system <sqlite3.h>
#ifdef GRDB_SQLITE_ENABLE_PREUPDATE_HOOK
SQLITE_API void *sqlite3_preupdate_hook(
  sqlite3 *db,
  void(*xPreUpdate)(
    void *pCtx,                   /* Copy of third arg to preupdate_hook() */
    sqlite3 *db,                  /* Database handle */
    int op,                       /* SQLITE_UPDATE, DELETE or INSERT */
    char const *zDb,              /* Database name */
    char const *zName,            /* Table name */
    sqlite3_int64 iKey1,          /* Rowid of row about to be deleted/updated */
    sqlite3_int64 iKey2           /* New rowid value (for a rowid UPDATE) */
  ),
  void*
);
SQLITE_API int sqlite3_preupdate_old(sqlite3 *, int, sqlite3_value **);
SQLITE_API int sqlite3_preupdate_count(sqlite3 *);
SQLITE_API int sqlite3_preupdate_depth(sqlite3 *);
SQLITE_API int sqlite3_preupdate_new(sqlite3 *, int, sqlite3_value **);
#endif /* GRDB_SQLITE_ENABLE_PREUPDATE_HOOK */

#endif /* grdb_config_h */
