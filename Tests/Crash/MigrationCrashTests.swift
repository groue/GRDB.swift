#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class MigrationCrashTests: GRDBCrashTestCase {
    
    func testMigrationNamesMustBeUnique() {
        assertCrash("already registered migration: \"foo\"") {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("foo") { db in }
            migrator.registerMigration("foo") { db in }
        }
    }
    
}
