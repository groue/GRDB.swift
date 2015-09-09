import XCTest
import GRDB

class RecordTestCase : GRDBTestCase {
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createPersons", Person.setupInDatabase)
        migrator.registerMigration("createPets", Pet.setupInDatabase)
        migrator.registerMigration("createItems", Item.setupInDatabase)
        migrator.registerMigration("createCitizenships", Citizenship.setupInDatabase)
        migrator.registerMigration("createMinimalRowIDs", MinimalRowID.setupInDatabase)
        migrator.registerMigration("createMinimalSingles", MinimalSingle.setupInDatabase)
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
}
