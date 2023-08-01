import XCTest
import GRDB

/// Test SQL generation

class AssociationHasManyThroughRowScopeTests: GRDBTestCase {
    
    func testBelongsToHasManySingularTable() throws {
        struct Parent: TableRecord {
            static let child = belongsTo(Child.self)
            static let grandChildren = hasMany(GrandChild.self, through: child, using: Child.grandChildren)
        }
        struct Child: TableRecord {
            static let grandChildren = hasMany(GrandChild.self)
        }
        struct GrandChild: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "child") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("child")
            }
            try db.create(table: "grandChild") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("child")
            }
            try db.execute(sql: """
                INSERT INTO child (id) VALUES (1);
                INSERT INTO parent (id, childId) VALUES (2, 1);
                INSERT INTO grandChild (id, childId) VALUES (3, 1);
                """)
            
            let request = Parent.including(required: Parent.grandChildren)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 2, "childId": 1])
            XCTAssertEqual(Set(row.scopes.names), ["child"])
            XCTAssertEqual(row.scopesTree["grandChild"], ["id": 3, "childId": 1])
        }
    }
    
    func testBelongsToHasManyPluralTable() throws {
        struct Parent: TableRecord {
            static let databaseTableName = "parents"
            static let child = belongsTo(Child.self)
            static let grandChildren = hasMany(GrandChild.self, through: child, using: Child.grandChildren)
        }
        struct Child: TableRecord {
            static let databaseTableName = "children"
            static let grandChildren = hasMany(GrandChild.self)
        }
        struct GrandChild: TableRecord {
            static let databaseTableName = "grandChildren"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "children") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "parents") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("child")
            }
            try db.create(table: "grandChildren") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("child")
            }
            try db.execute(sql: """
                INSERT INTO children (id) VALUES (1);
                INSERT INTO parents (id, childId) VALUES (2, 1);
                INSERT INTO grandChildren (id, childId) VALUES (3, 1);
                """)
            
            let request = Parent.including(required: Parent.grandChildren)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 2, "childId": 1])
            XCTAssertEqual(Set(row.scopes.names), ["child"])
            XCTAssertEqual(row.scopesTree["grandChild"], ["id": 3, "childId": 1])
        }
    }
    
    func testBelongsToHasManyCustomKey() throws {
        struct Parent: TableRecord {
            static let databaseTableName = "parents"
            static let child = belongsTo(Child.self)
            static let littlePuppies = hasMany(GrandChild.self, through: child, using: Child.grandChildren, key: "littlePuppies")
            static let kittens = hasMany(GrandChild.self, through: child, using: Child.grandChildren).forKey("kittens")
        }
        struct Child: TableRecord {
            static let databaseTableName = "children"
            static let grandChildren = hasMany(GrandChild.self)
        }
        struct GrandChild: TableRecord {
            static let databaseTableName = "grandChildren"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "children") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "parents") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("child")
            }
            try db.create(table: "grandChildren") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("child")
            }
            try db.execute(sql: """
                INSERT INTO children (id) VALUES (1);
                INSERT INTO parents (id, childId) VALUES (2, 1);
                INSERT INTO grandChildren (id, childId) VALUES (3, 1);
                """)
            
            do {
                let request = Parent.including(required: Parent.littlePuppies)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 2, "childId": 1])
                XCTAssertEqual(Set(row.scopes.names), ["child"])
                XCTAssertEqual(row.scopesTree["littlePuppy"], ["id": 3, "childId": 1])
            }
            
            do {
                let request = Parent.including(required: Parent.kittens)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 2, "childId": 1])
                XCTAssertEqual(Set(row.scopes.names), ["child"])
                XCTAssertEqual(row.scopesTree["kitten"], ["id": 3, "childId": 1])
            }
        }
    }
    
    func testHasManyBelongsToSingularTable() throws {
        struct Parent: TableRecord {
            static let children = hasMany(Child.self)
            static let grandChildren = hasMany(GrandChild.self, through: children, using: Child.grandChild)
        }
        struct Child: TableRecord {
            static let grandChild = belongsTo(GrandChild.self)
        }
        struct GrandChild: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "grandChild") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "child") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("parent")
                t.belongsTo("grandChild")
            }
            try db.execute(sql: """
                INSERT INTO parent (id) VALUES (1);
                INSERT INTO grandChild (id) VALUES (2);
                INSERT INTO child (id, parentId, grandChildId) VALUES (3, 1, 2);
                """)
            
            let request = Parent.including(required: Parent.grandChildren)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 1])
            XCTAssertEqual(Set(row.scopes.names), ["child"])
            XCTAssertEqual(row.scopesTree["grandChild"], ["id": 2])
        }
    }
    
    func testHasManyBelongsToPluralTable() throws {
        struct Parent: TableRecord {
            static let databaseTableName = "parents"
            static let children = hasMany(Child.self)
            static let grandChildren = hasMany(GrandChild.self, through: children, using: Child.grandChild)
        }
        struct Child: TableRecord {
            static let databaseTableName = "children"
            static let grandChild = belongsTo(GrandChild.self)
        }
        struct GrandChild: TableRecord {
            static let databaseTableName = "grandChildren"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "parents") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "grandChildren") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "children") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("parent")
                t.belongsTo("grandChild")
            }
            try db.execute(sql: """
                INSERT INTO parents (id) VALUES (1);
                INSERT INTO grandChildren (id) VALUES (2);
                INSERT INTO children (id, parentId, grandChildId) VALUES (3, 1, 2);
                """)
            
            let request = Parent.including(required: Parent.grandChildren)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 1])
            XCTAssertEqual(Set(row.scopes.names), ["child"])
            XCTAssertEqual(row.scopesTree["grandChild"], ["id": 2])
        }
    }
    
    func testHasManyBelongsToCustomKey() throws {
        struct Parent: TableRecord {
            static let children = hasMany(Child.self)
            static let littlePuppies = hasMany(GrandChild.self, through: children, using: Child.grandChild, key: "littlePuppies")
            static let kittens = hasMany(GrandChild.self, through: children, using: Child.grandChild).forKey("kittens")
        }
        struct Child: TableRecord {
            static let grandChild = belongsTo(GrandChild.self)
        }
        struct GrandChild: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "grandChild") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "child") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("parent")
                t.belongsTo("grandChild")
            }
            try db.execute(sql: """
                INSERT INTO parent (id) VALUES (1);
                INSERT INTO grandChild (id) VALUES (2);
                INSERT INTO child (id, parentId, grandChildId) VALUES (3, 1, 2);
                """)
            
            do {
                let request = Parent.including(required: Parent.littlePuppies)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 1])
                XCTAssertEqual(Set(row.scopes.names), ["child"])
                XCTAssertEqual(row.scopesTree["littlePuppy"], ["id": 2])
            }
            
            do {
                let request = Parent.including(required: Parent.kittens)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 1])
                XCTAssertEqual(Set(row.scopes.names), ["child"])
                XCTAssertEqual(row.scopesTree["kitten"], ["id": 2])
            }
        }
    }
    
    // https://github.com/groue/GRDB.swift/discussions/1274
    func testDiscussion1274() throws {
        struct MuscleGroup: Codable, Equatable, FetchableRecord, TableRecord {
            var id: String
          
            static let primaryMuscleGroups = hasMany(PrimaryMuscleGroup.self)
            static let primaryExercises = hasMany(
                  Exercise.self,
                  through: primaryMuscleGroups,
                  using: PrimaryMuscleGroup.exercise
            )
        }

        struct Exercise: Codable, Equatable, FetchableRecord, TableRecord {
            var id: String
          
            // Primary Muscle Groups
            static let primaryMuscleGroups = hasMany(
                MuscleGroup.self,
                // Tested: this has the "primaryMuscleGroups" key, just
                // as Exercise.primaryMuscleGroups
                through: Exercise.hasMany(PrimaryMuscleGroup.self),
                using: PrimaryMuscleGroup.muscleGroup
            )
            .forKey("primaryMuscleGroups")
        }

        struct PrimaryMuscleGroup: Codable, FetchableRecord, TableRecord {
            var muscleGroupId: String
            var exerciseId: String
          
            static let muscleGroup = belongsTo(MuscleGroup.self)
            static let exercise = belongsTo(Exercise.self)
        }

        struct CompleteExercise: Decodable, Equatable, FetchableRecord {
            var exercise: Exercise
            var primaryMuscleGroups: [MuscleGroup]
        }
        
        dbConfiguration.prepareDatabase { db in
            db.trace { print("SQL > \($0)") }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "muscleGroup") { table in
                table.primaryKey("id", .text)
            }
            try db.create(table: "exercise") { table in
                table.primaryKey("id", .text)
            }
            try db.create(table: "primaryMuscleGroup") { table in
                table.column("muscleGroupId", .text).notNull().references("muscleGroup", onDelete: .cascade)
                table.column("exerciseId", .text).notNull().references("exercise", onDelete: .cascade)
                table.primaryKey(["muscleGroupId", "exerciseId"])
            }
            
            try db.execute(sql: """
                INSERT INTO muscleGroup (id) VALUES ('1');
                INSERT INTO exercise (id) VALUES ('2');
                INSERT INTO primaryMuscleGroup (muscleGroupId, exerciseId) VALUES ('1', '2');
                """)
            
            let request = Exercise.including(all: Exercise.primaryMuscleGroups)
            
            do {
                // Test records
                let results = try request
                    .asRequest(of: CompleteExercise.self)
                    .fetchAll(db)
                XCTAssertEqual(results, [
                    CompleteExercise(
                        exercise: Exercise(id: "2"),
                        primaryMuscleGroups: [
                            MuscleGroup(id: "1"),
                        ]),
                ])
            }
        }
    }
}
