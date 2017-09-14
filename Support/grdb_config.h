#ifndef grdb_config_h
#define grdb_config_h

#if defined(COCOAPODS)
    #if defined(GRDBCIPHER)
        #include <SQLCipher/sqlite3.h>
    #else
        #include <sqlite3.h>
    #endif
#else
    #if defined(GRDBCIPHER)
        #include <GRDBCipher/sqlite3.h>
    #elsif defined(GRDBCUSTOMSQLITE)
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

#endif /* grdb_config_h */
