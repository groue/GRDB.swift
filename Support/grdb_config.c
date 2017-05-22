#if GRDBCIPHER && defined(COCOAPODS)
    #include <GRDBCipher/grdb_config.h>
    #include <SQLCipher/sqlite3.h>
#else
    #include <GRDB/grdb_config.h>
    #include <GRDB/sqlite3.h>
#endif


void registerErrorLogCallback(errorLogCallback callback) {
    sqlite3_config(SQLITE_CONFIG_LOG, callback, 0);
}
