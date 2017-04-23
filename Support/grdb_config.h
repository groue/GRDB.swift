#ifndef grdb_config_h
#define grdb_config_h

typedef void(*errorLogCallback)(void *pArg, int iErrCode, const char *zMsg);

// Wrapper around sqlite3_config(SQLITE_CONFIG_LOG, ...) which is a variadic
// function that can't be used from Swift.
void registerErrorLogCallback(errorLogCallback callback);

#endif /* grdb_config_h */
