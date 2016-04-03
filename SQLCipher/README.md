General doc: https://www.zetetic.net/sqlcipher/ios-tutorial/

TODO: Look for "verification" in https://www.zetetic.net/sqlcipher/design/

Compilation options used of the stock SQLite shipped with Apple Operating systems (String.fetchAll(dbQueue, "PRAGMA compile_options")):

- MacOSX SDK
    - ENABLE_API_ARMOR
    - ENABLE_FTS3
    - ENABLE_FTS3_PARENTHESIS
    - ENABLE_LOCKING_STYLE=1
    - ENABLE_RTREE
    - ENABLE_UPDATE_DELETE_LIMIT
    - OMIT_AUTORESET
    - OMIT_BUILTIN_TEST
    - OMIT_LOAD_EXTENSION
    - SYSTEM_MALLOC
    - THREADSAFE=2

- iPhoneSimulator SDK
    - ENABLE_API_ARMOR
    - ENABLE_FTS3
    - ENABLE_FTS3_PARENTHESIS
    - ENABLE_LOCKING_STYLE=1
    - ENABLE_RTREE
    - ENABLE_UPDATE_DELETE_LIMIT
    - MAX_MMAP_SIZE=0
    - OMIT_AUTORESET
    - OMIT_BUILTIN_TEST
    - OMIT_LOAD_EXTENSION
    - SYSTEM_MALLOC
    - THREADSAFE=2

- iPhoneOS SDK
    - ENABLE_API_ARMOR
    - ENABLE_FTS3
    - ENABLE_FTS3_PARENTHESIS
    - ENABLE_LOCKING_STYLE=1
    - ENABLE_RTREE
    - ENABLE_UPDATE_DELETE_LIMIT
    - MAX_MMAP_SIZE=0
    - OMIT_AUTORESET
    - OMIT_BUILTIN_TEST
    - OMIT_LOAD_EXTENSION
    - SYSTEM_MALLOC
    - THREADSAFE=2
