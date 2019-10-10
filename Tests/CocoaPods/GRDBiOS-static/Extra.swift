import GRDB

func test_SQLITE_ENABLE_FTS5() {
    _ = FTS5.self
}

func test_SQLITE_ENABLE_PREUPDATE_HOOK() {
    _ = DatabasePreUpdateEvent.self
}
