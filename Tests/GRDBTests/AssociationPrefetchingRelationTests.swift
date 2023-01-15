import XCTest
@testable import GRDB

class AssociationPrefetchingRelationTests: GRDBTestCase {
    func testAssociationKeyInflections() {
        do {
            let key = SQLAssociationKey.inflected("player")
            XCTAssertEqual(key.baseName, "player")
            XCTAssertEqual(key.singularizedName, "player")
            XCTAssertEqual(key.pluralizedName, "players")
            XCTAssertEqual(key.name(singular: true), "player")
            XCTAssertEqual(key.name(singular: false), "players")
        }
        do {
            let key = SQLAssociationKey.fixedSingular("player")
            XCTAssertEqual(key.baseName, "player")
            XCTAssertEqual(key.singularizedName, "player")
            XCTAssertEqual(key.pluralizedName, "players")
            XCTAssertEqual(key.name(singular: true), "player")
            XCTAssertEqual(key.name(singular: false), "players")
        }
        do {
            let key = SQLAssociationKey.fixedSingular("players")
            XCTAssertEqual(key.baseName, "players")
            XCTAssertEqual(key.singularizedName, "players")
            XCTAssertEqual(key.pluralizedName, "players")
            XCTAssertEqual(key.name(singular: true), "players")
            XCTAssertEqual(key.name(singular: false), "players")
        }
        do {
            let key = SQLAssociationKey.fixedPlural("player")
            XCTAssertEqual(key.baseName, "player")
            XCTAssertEqual(key.singularizedName, "player")
            XCTAssertEqual(key.pluralizedName, "player")
            XCTAssertEqual(key.name(singular: true), "player")
            XCTAssertEqual(key.name(singular: false), "player")
        }
        do {
            let key = SQLAssociationKey.fixedPlural("players")
            XCTAssertEqual(key.baseName, "players")
            XCTAssertEqual(key.singularizedName, "player")
            XCTAssertEqual(key.pluralizedName, "players")
            XCTAssertEqual(key.name(singular: true), "player")
            XCTAssertEqual(key.name(singular: false), "players")
        }
        do {
            let key = SQLAssociationKey.fixed("player")
            XCTAssertEqual(key.baseName, "player")
            XCTAssertEqual(key.singularizedName, "player")
            XCTAssertEqual(key.pluralizedName, "player")
            XCTAssertEqual(key.name(singular: true), "player")
            XCTAssertEqual(key.name(singular: false), "player")
        }
        do {
            let key = SQLAssociationKey.fixed("players")
            XCTAssertEqual(key.baseName, "players")
            XCTAssertEqual(key.singularizedName, "players")
            XCTAssertEqual(key.pluralizedName, "players")
            XCTAssertEqual(key.name(singular: true), "players")
            XCTAssertEqual(key.name(singular: false), "players")
        }
    }
    
    func testOneStep() {
        let cardinalities: [SQLAssociationCardinality] = [
            .toOne,
            .toMany,
        ]
        
        let keys: [SQLAssociationKey] = [
            .inflected("player"),
            .fixedSingular("player"),
            .fixedSingular("players"),
            .fixedPlural("player"),
            .fixedPlural("players"),
            .fixed("player"),
        ]
        
        for cardinality in cardinalities {
            for key in keys {
                
                let relation = SQLRelation.all(fromTable: "ignored")
                
                let association = _SQLAssociation(
                    key: key,
                    condition: .none,
                    relation: .all(fromTable: "ignored"),
                    cardinality: cardinality)
                
                for relation in [
                    relation._joining(optional: association),
                    relation._including(optional: association),
                ] {
                    do {
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                    }
                    do {
                        let relation = relation._joining(optional: association)
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                    }
                    do {
                        let relation = relation._joining(required: association)
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                    }
                    do {
                        let relation = relation._including(optional: association)
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                    }
                    do {
                        let relation = relation._including(required: association)
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                    }
                    if key.name(singular: true) != key.name(singular: false) {
                        let relation = relation._including(all: association)
                        XCTAssertEqual(relation.children.count, 2)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                        XCTAssertEqual(relation.children[1].key, key.name(singular: false))
                        XCTAssertEqual(relation.children[1].value.kind, .all)
                    }
                }
                
                for relation in [
                    relation._joining(required: association),
                    relation._including(required: association),
                ] {
                    do {
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                    }
                    do {
                        let relation = relation._joining(optional: association)
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                    }
                    do {
                        let relation = relation._joining(required: association)
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                    }
                    do {
                        let relation = relation._including(optional: association)
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                    }
                    do {
                        let relation = relation._including(required: association)
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                    }
                    if key.name(singular: true) != key.name(singular: false) {
                        let relation = relation._including(all: association)
                        XCTAssertEqual(relation.children.count, 2)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                        XCTAssertEqual(relation.children[1].key, key.name(singular: false))
                        XCTAssertEqual(relation.children[1].value.kind, .all)
                    }
                }
                
                do {
                    let relation = relation._including(all: association)
                    do {
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: false))
                        XCTAssertEqual(relation.children[0].value.kind, .all)
                    }
                    if key.name(singular: true) != key.name(singular: false) {
                        let relation = relation._joining(optional: association)
                        XCTAssertEqual(relation.children.count, 2)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: false))
                        XCTAssertEqual(relation.children[0].value.kind, .all)
                        XCTAssertEqual(relation.children[1].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[1].value.kind, .oneOptional)
                    }
                    if key.name(singular: true) != key.name(singular: false) {
                        let relation = relation._joining(required: association)
                        XCTAssertEqual(relation.children.count, 2)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: false))
                        XCTAssertEqual(relation.children[0].value.kind, .all)
                        XCTAssertEqual(relation.children[1].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[1].value.kind, .oneRequired)
                    }
                    if key.name(singular: true) != key.name(singular: false) {
                        let relation = relation._including(optional: association)
                        XCTAssertEqual(relation.children.count, 2)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: false))
                        XCTAssertEqual(relation.children[0].value.kind, .all)
                        XCTAssertEqual(relation.children[1].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[1].value.kind, .oneOptional)
                    }
                    if key.name(singular: true) != key.name(singular: false) {
                        let relation = relation._including(required: association)
                        XCTAssertEqual(relation.children.count, 2)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: false))
                        XCTAssertEqual(relation.children[0].value.kind, .all)
                        XCTAssertEqual(relation.children[1].key, key.name(singular: true))
                        XCTAssertEqual(relation.children[1].value.kind, .oneRequired)
                    }
                    do {
                        let relation = relation._including(all: association)
                        XCTAssertEqual(relation.children.count, 1)
                        XCTAssertEqual(relation.children[0].key, key.name(singular: false))
                        XCTAssertEqual(relation.children[0].value.kind, .all)
                    }
                }
            }
        }
    }
    
    func testTwoSteps() {
        let cardinalities: [SQLAssociationCardinality] = [
            .toOne,
            .toMany,
        ]
        
        let keys1: [SQLAssociationKey] = [
            .inflected("player"),
            .fixedSingular("player"),
            .fixedSingular("players"),
            .fixedPlural("player"),
            .fixedPlural("players"),
            .fixed("player"),
        ]
        
        let keys2: [SQLAssociationKey] = [
            .inflected("award"),
            .fixedSingular("award"),
            .fixedSingular("awards"),
            .fixedPlural("award"),
            .fixedPlural("awards"),
            .fixed("award"),
        ]
        
        for cardinality1 in cardinalities {
            for key1 in keys1 {
                for cardinality2 in cardinalities {
                    for key2 in keys2 {
                        let relation = SQLRelation.all(fromTable: "ignored")
                        
                        let association1 = _SQLAssociation(
                            key: key1,
                            condition: .none,
                            relation: .all(fromTable: "ignored"),
                            cardinality: cardinality1)
                        
                        let association2 = _SQLAssociation(
                            key: key2,
                            condition: .none,
                            relation: .all(fromTable: "ignored"),
                            cardinality: cardinality2)
                        
                        let association = association2.through(association1)
                        
                        for relation in [
                            relation._joining(optional: association),
                            relation._including(optional: association),
                        ] {
                            do {
                                XCTAssertEqual(relation.children.count, 1)
                                XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                                XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                            }
                            do {
                                do {
                                    let relation = relation._joining(optional: association1)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                }
                                do {
                                    let relation = relation._joining(required: association1)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                }
                                do {
                                    let relation = relation._including(optional: association1)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                }
                                do {
                                    let relation = relation._including(required: association1)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                }
                                if !cardinality1.isSingular && key1.name(singular: true) != key1.name(singular: false) {
                                    let relation = relation._including(all: association1)
                                    XCTAssertEqual(relation.children.count, 2)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                    XCTAssertEqual(relation.children[1].key, key1.name(singular: false))
                                    XCTAssertEqual(relation.children[1].value.kind, .all)
                                    XCTAssertEqual(relation.children[1].value.relation.children.count, 0)
                                }
                            }
                            do {
                                do {
                                    let relation = relation._joining(optional: association)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                }
                                do {
                                    let relation = relation._joining(required: association)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                do {
                                    let relation = relation._including(optional: association)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                }
                                do {
                                    let relation = relation._including(required: association)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                if !cardinality1.isSingular && key1.name(singular: true) != key1.name(singular: false) {
                                    let relation = relation._including(all: association)
                                    XCTAssertEqual(relation.children.count, 2)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                    XCTAssertEqual(relation.children[1].key, key1.name(singular: cardinality1.isSingular))
                                    XCTAssertEqual(relation.children[1].value.kind, .bridge)
                                    XCTAssertEqual(relation.children[1].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[1].value.relation.children[0].key, key2.name(singular: false))
                                    XCTAssertEqual(relation.children[1].value.relation.children[0].value.kind, .all)
                                }
                            }
                        }
                        
                        for relation in [
                            relation._joining(required: association),
                            relation._including(required: association),
                        ] {
                            do {
                                XCTAssertEqual(relation.children.count, 1)
                                XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                            }
                            do {
                                do {
                                    let relation = relation._joining(optional: association1)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                do {
                                    let relation = relation._joining(required: association1)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                do {
                                    let relation = relation._including(optional: association1)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                do {
                                    let relation = relation._including(required: association1)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                if !cardinality1.isSingular && key1.name(singular: true) != key1.name(singular: false) {
                                    let relation = relation._including(all: association1)
                                    XCTAssertEqual(relation.children.count, 2)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[1].key, key1.name(singular: false))
                                    XCTAssertEqual(relation.children[1].value.kind, .all)
                                    XCTAssertEqual(relation.children[1].value.relation.children.count, 0)
                                }
                            }
                            do {
                                do {
                                    let relation = relation._joining(optional: association)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                do {
                                    let relation = relation._joining(required: association)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                do {
                                    let relation = relation._including(optional: association)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                do {
                                    let relation = relation._including(required: association)
                                    XCTAssertEqual(relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                }
                                if !cardinality1.isSingular && key1.name(singular: true) != key1.name(singular: false) {
                                    let relation = relation._including(all: association)
                                    XCTAssertEqual(relation.children.count, 2)
                                    XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                    XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                    XCTAssertEqual(relation.children[1].key, key1.name(singular: cardinality1.isSingular))
                                    XCTAssertEqual(relation.children[1].value.kind, .bridge)
                                    XCTAssertEqual(relation.children[1].value.relation.children.count, 1)
                                    XCTAssertEqual(relation.children[1].value.relation.children[0].key, key2.name(singular: false))
                                    XCTAssertEqual(relation.children[1].value.relation.children[0].value.kind, .all)
                                }
                            }
                        }
                        
                        do {
                            let relation = relation._including(all: association)
                            do {
                                XCTAssertEqual(relation.children.count, 1)
                                XCTAssertEqual(relation.children[0].key, key1.name(singular: cardinality1.isSingular))
                                XCTAssertEqual(relation.children[0].value.kind, .bridge)
                                XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: false))
                                XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .all)
                            }
                            
                            // TODO: here we see the problem: it should be possible to merge association1 when it is singular.
                            if !cardinality1.isSingular && key1.name(singular: true) != key1.name(singular: false) {
                                let relation = relation._joining(optional: association1)
                                XCTAssertEqual(relation.children.count, 2)
                                XCTAssertEqual(relation.children[0].key, key1.name(singular: cardinality1.isSingular))
                                XCTAssertEqual(relation.children[0].value.kind, .bridge)
                                XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: false))
                                XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .all)
                                XCTAssertEqual(relation.children[1].key, key1.name(singular: true))
                                XCTAssertEqual(relation.children[1].value.kind, .oneOptional)
                                XCTAssertEqual(relation.children[1].value.relation.children.count, 0)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func testThreeSteps() {
        let cardinalities: [SQLAssociationCardinality] = [
            .toOne,
            .toMany,
        ]
        
        let keys1: [SQLAssociationKey] = [
            .inflected("player"),
            .fixedSingular("player"),
            .fixedSingular("players"),
            .fixedPlural("player"),
            .fixedPlural("players"),
            .fixed("player"),
        ]
        
        let keys2: [SQLAssociationKey] = [
            .inflected("award"),
            .fixedSingular("award"),
            .fixedSingular("awards"),
            .fixedPlural("award"),
            .fixedPlural("awards"),
            .fixed("award"),
        ]
        
        let keys3: [SQLAssociationKey] = [
            .inflected("sponsor"),
            .fixedSingular("sponsor"),
            .fixedSingular("sponsors"),
            .fixedPlural("sponsor"),
            .fixedPlural("sponsors"),
            .fixed("sponsor"),
        ]
        
        for cardinality1 in cardinalities {
            for key1 in keys1 {
                for cardinality2 in cardinalities {
                    for key2 in keys2 {
                        for cardinality3 in cardinalities {
                            for key3 in keys3 {
                                let relation = SQLRelation.all(fromTable: "ignored")
                                
                                let association1 = _SQLAssociation(
                                    key: key1,
                                    condition: .none,
                                    relation: .all(fromTable: "ignored"),
                                    cardinality: cardinality1)
                                
                                let association2 = _SQLAssociation(
                                    key: key2,
                                    condition: .none,
                                    relation: .all(fromTable: "ignored"),
                                    cardinality: cardinality2)
                                
                                let association3 = _SQLAssociation(
                                    key: key3,
                                    condition: .none,
                                    relation: .all(fromTable: "ignored"),
                                    cardinality: cardinality3)
                                
                                for association in [
                                    association3.through(association2.through(association1)),
                                    association3.through(association2).through(association1),
                                ] {
                                    
                                    for relation in [
                                        relation._joining(optional: association),
                                        relation._including(optional: association),
                                    ] {
                                        do {
                                            XCTAssertEqual(relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                                            XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].key, key3.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                        }
                                        do {
                                            let relation = relation._joining(optional: association1)
                                            XCTAssertEqual(relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.kind, .oneOptional)
                                            XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].key, key3.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].value.kind, .oneOptional)
                                        }
                                    }
                                    
                                    for relation in [
                                        relation._joining(required: association),
                                        relation._including(required: association),
                                    ] {
                                        do {
                                            XCTAssertEqual(relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                            XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].key, key3.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                        }
                                        do {
                                            let relation = relation._joining(optional: association1)
                                            XCTAssertEqual(relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].key, key1.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.kind, .oneRequired)
                                            XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].key, key3.name(singular: true))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].value.kind, .oneRequired)
                                        }
                                    }
                                    
                                    do {
                                        let relation = relation._including(all: association)
                                        do {
                                            XCTAssertEqual(relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].key, key1.name(singular: cardinality1.isSingular))
                                            XCTAssertEqual(relation.children[0].value.kind, .bridge)
                                            XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: cardinality2.isSingular))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .bridge)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].key, key3.name(singular: false))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].value.kind, .all)
                                        }
                                        // TODO: here we see the problem: it should be possible to merge association1 when it is singular.
                                        if !cardinality1.isSingular && key1.name(singular: true) != key1.name(singular: false) {
                                            let relation = relation._joining(optional: association1)
                                            XCTAssertEqual(relation.children.count, 2)
                                            XCTAssertEqual(relation.children[0].key, key1.name(singular: cardinality1.isSingular))
                                            XCTAssertEqual(relation.children[0].value.kind, .bridge)
                                            XCTAssertEqual(relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].key, key2.name(singular: cardinality2.isSingular))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.kind, .bridge)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children.count, 1)
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].key, key3.name(singular: false))
                                            XCTAssertEqual(relation.children[0].value.relation.children[0].value.relation.children[0].value.kind, .all)
                                            XCTAssertEqual(relation.children[1].key, key1.name(singular: true))
                                            XCTAssertEqual(relation.children[1].value.kind, .oneOptional)
                                            XCTAssertEqual(relation.children[1].value.relation.children.count, 0)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1315>
    func testIssue1315() throws {
        struct A: TableRecord {
            static let b = belongsTo(B.self)
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
            static let e = hasOne(E.self)
        }
        struct C: TableRecord {
            static let ds = hasMany(D.self)
        }
        struct D: TableRecord { }
        struct E: TableRecord {
            static let fs = hasMany(F.self)
        }
        struct F: TableRecord { }
        
        try DatabaseQueue().write { db in
            try db.execute(sql: """
                CREATE TABLE b (id INTEGER PRIMARY KEY);
                CREATE TABLE a (id INTEGER PRIMARY KEY, bId INTEGER REFERENCES b(id));
                CREATE TABLE c (id INTEGER PRIMARY KEY, bId INTEGER REFERENCES b(id));
                CREATE TABLE d (id INTEGER PRIMARY KEY, cId INTEGER REFERENCES c(id));
                CREATE TABLE e (id INTEGER PRIMARY KEY, bId INTEGER REFERENCES b(id));
                CREATE TABLE f (id INTEGER PRIMARY KEY, eId INTEGER REFERENCES e(id));
                """)
            
            let region = try A
                .including(required: A.b
                    .including(optional: B.c.including(all: C.ds))
                    .including(optional: B.e.including(all: E.fs)))
                .databaseRegion(db)
            
            XCTAssertTrue(region.isModified(byEventsOfKind: .insert(tableName: "a")))
            XCTAssertTrue(region.isModified(byEventsOfKind: .insert(tableName: "b")))
            XCTAssertTrue(region.isModified(byEventsOfKind: .insert(tableName: "c")))
            XCTAssertTrue(region.isModified(byEventsOfKind: .insert(tableName: "d")))
            XCTAssertTrue(region.isModified(byEventsOfKind: .insert(tableName: "e")))
            XCTAssertTrue(region.isModified(byEventsOfKind: .insert(tableName: "f")))
        }
    }
}
