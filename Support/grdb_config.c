#include <GRDB/grdb_config.h>
#if SQLITE_HAS_CODEC
    #include <SQLCipher/sqlite3.h>
#else
    #include <GRDB/sqlite3.h>
#endif


void registerErrorLogCallback(errorLogCallback callback) {
    sqlite3_config(SQLITE_CONFIG_LOG, callback, 0);
}
