import XCTest
import GRDB

class FetchedResultsSectionInfo<T: RowConvertible> {
    let name: String?
    var numberOfObjects: Int {
        return objects.count
    }
    let objects: [T]
    private init(name: String?, objects: [T]) {
        self.name = name
        self.objects = objects
    }
}

class FetchedResultsController<T: RowConvertible> {
    let statement: SelectStatement
    
    var fetchedObjects: [T] {
        return sections.flatMap { $0.objects }
    }
    
    init(statement: SelectStatement, sectionName: (T -> String?)?) {
        self.statement = statement
        self.sectionName = sectionName
    }
    
    func performFetch() {
        if let sectionName = sectionName {
            var sections: [FetchedResultsSectionInfo<T>] = []
            var sectionObjects: [T] = []
            var previousName: String??
            for object in T.fetch(statement) {
                let name = sectionName(object)
                if let previousName = previousName where previousName == name {
                    sectionObjects.append(object)
                } else {
                    if sectionObjects.count > 0 {
                        sections.append(FetchedResultsSectionInfo(name: name, objects: sectionObjects))
                        sectionObjects = []
                    }
                    previousName = name
                }
            }
            if sectionObjects.count > 0 || sections.count == 0 {
                sections.append(FetchedResultsSectionInfo(name: previousName ?? nil, objects: sectionObjects))
            }
            self.sections = sections
        } else {
            self.sections = [FetchedResultsSectionInfo(name: nil, objects: T.fetchAll(statement))]
        }
    }
    
    private var sections: [FetchedResultsSectionInfo<T>] = []
    private var sectionName: (T -> String?)?
}

class FetchedResultsControllerTests: GRDBTestCase {
}
