#include <GRDB/grdb_config.h>
#include <GRDB/sqlite3.h>

void registerErrorLogCallback(errorLogCallback callback) {
    sqlite3_config(SQLITE_CONFIG_LOG, callback, 0);
}
