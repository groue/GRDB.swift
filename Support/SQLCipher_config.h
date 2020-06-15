#ifndef grdb_config_h
#define grdb_config_h

#include <SQLCipher/sqlite3.h>

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
static inline int grdb_snapshot_get(
  sqlite3 *db,
  const char *zSchema,
  sqlite3_snapshot **ppSnapshot)
{
    return SQLITE_MISUSE;
}

static inline void grdb_snapshot_free(sqlite3_snapshot* ppSnapshot) {
}

static inline int grdb_snapshot_cmp(
  sqlite3_snapshot *p1,
  sqlite3_snapshot *p2)
{
    return 0;
}
#endif /* SQLITE_ENABLE_SNAPSHOT */

#endif /* grdb_config_h */
