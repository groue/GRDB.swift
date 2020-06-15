#ifndef grdb_config_h
#define grdb_config_h

#include <sqlite3.h>

typedef void(*errorLogCallback)(void *pArg, int iErrCode, const char *zMsg);

/// Wrapper around sqlite3_config(SQLITE_CONFIG_LOG, ...) which is a variadic
/// function that can't be used from Swift.
static inline void registerErrorLogCallback(errorLogCallback callback) {
    sqlite3_config(SQLITE_CONFIG_LOG, callback, 0);
}

#if SQLITE_VERSION_NUMBER >= 3029000
/// Wrapper around sqlite3_db_config() which is a variadic function that can't
/// be used from Swift.
static inline void disableDoubleQuotedStringLiterals(sqlite3 *db) {
    sqlite3_db_config(db, SQLITE_DBCONFIG_DQS_DDL, 0, (void *)0);
    sqlite3_db_config(db, SQLITE_DBCONFIG_DQS_DML, 0, (void *)0);
}

/// Wrapper around sqlite3_db_config() which is a variadic function that can't
/// be used from Swift.
static inline void enableDoubleQuotedStringLiterals(sqlite3 *db) {
    sqlite3_db_config(db, SQLITE_DBCONFIG_DQS_DDL, 1, (void *)0);
    sqlite3_db_config(db, SQLITE_DBCONFIG_DQS_DML, 1, (void *)0);
}
#else
static inline void disableDoubleQuotedStringLiterals(sqlite3 *db) { }
static inline void enableDoubleQuotedStringLiterals(sqlite3 *db) { }
#endif

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

/*
 Snapshots
 =========
 
 We have a linker/C-interop difficulty here:

 - Not all SQLite versions ship with the sqlite3_snapshot_get function.
 - Not all iOS/macOS versions ship a <sqlite3.h> header that contains
   the declaration for sqlite3_snapshot_get(), even when SQLite is
   actually compiled with SQLITE_ENABLE_SNAPSHOT.

 This makes it really difficult to deal with system SQLite, custom
 SQLite builds, SQLCipher, and SPM.

 To avoid those problems, we add grdb_snapshot_xxx shim functions in the
 following header files:

 - SQLiteCustom/grdb_config.h
 - Sources/CSQLite/shim.h
 - Support/grdb_config.h
 */
#ifdef SQLITE_ENABLE_SNAPSHOT
static inline int grdb_snapshot_get(
  sqlite3 *db,
  const char *zSchema,
  sqlite3_snapshot **ppSnapshot)
{
    return sqlite3_snapshot_get(db, zSchema, ppSnapshot);
}

static inline void grdb_snapshot_free(sqlite3_snapshot* ppSnapshot) {
    sqlite3_snapshot_free(ppSnapshot);
}

static inline int grdb_snapshot_cmp(
  sqlite3_snapshot *p1,
  sqlite3_snapshot *p2)
{
    return sqlite3_snapshot_cmp(p1, p2);
}
#else
// Assume snapshot apis *are* defined, but not exposed.
typedef struct sqlite3_snapshot {
  unsigned char hidden[48];
} sqlite3_snapshot;

SQLITE_API SQLITE_EXPERIMENTAL int sqlite3_snapshot_get(
  sqlite3 *db,
  const char *zSchema,
  sqlite3_snapshot **ppSnapshot
);

SQLITE_API SQLITE_EXPERIMENTAL void sqlite3_snapshot_free(sqlite3_snapshot*);

SQLITE_API SQLITE_EXPERIMENTAL int sqlite3_snapshot_cmp(
  sqlite3_snapshot *p1,
  sqlite3_snapshot *p2
);

static inline int grdb_snapshot_get(
  sqlite3 *db,
  const char *zSchema,
  sqlite3_snapshot **ppSnapshot)
{
    return sqlite3_snapshot_get(db, zSchema, ppSnapshot);
}

static inline void grdb_snapshot_free(sqlite3_snapshot* ppSnapshot) {
    sqlite3_snapshot_free(ppSnapshot);
}

static inline int grdb_snapshot_cmp(
  sqlite3_snapshot *p1,
  sqlite3_snapshot *p2)
{
    return sqlite3_snapshot_cmp(p1, p2);
}
#endif /* SQLITE_ENABLE_SNAPSHOT */
#endif /* grdb_config_h */
