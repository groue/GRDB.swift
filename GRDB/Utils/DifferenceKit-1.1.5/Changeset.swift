/// A set of changes in the sectioned collection.
///
/// Changes to the section of the linear collection should be empty.
///
/// Notice that the value of the changes represents offsets of collection not index.
/// Since offsets are unordered, order is ignored when comparing two `Changeset`s.
public struct Changeset<Collection: Swift.Collection> {
    /// The collection after changed.
    public var data: Collection

    /// The offsets of deleted sections.
    public var sectionDeleted: [Int]
    /// The offsets of inserted sections.
    public var sectionInserted: [Int]
    /// The offsets of updated sections.
    public var sectionUpdated: [Int]
    /// The pairs of source and target offset of moved sections.
    public var sectionMoved: [(source: Int, target: Int)]

    /// The paths of deleted elements.
    public var elementDeleted: [ElementPath]
    /// The paths of inserted elements.
    public var elementInserted: [ElementPath]
    /// The paths of updated elements.
    public var elementUpdated: [ElementPath]
    /// The pairs of source and target path of moved elements.
    public var elementMoved: [(source: ElementPath, target: ElementPath)]

    /// Creates a new `Changeset`.
    ///
    /// - Parameters:
    ///   - data: The collection after changed.
    ///   - sectionDeleted: The offsets of deleted sections.
    ///   - sectionInserted: The offsets of inserted sections.
    ///   - sectionUpdated: The offsets of updated sections.
    ///   - sectionMoved: The pairs of source and target offset of moved sections.
    ///   - elementDeleted: The paths of deleted elements.
    ///   - elementInserted: The paths of inserted elements.
    ///   - elementUpdated: The paths of updated elements.
    ///   - elementMoved: The pairs of source and target path of moved elements.
    public init(
        data: Collection,
        sectionDeleted: [Int] = [],
        sectionInserted: [Int] = [],
        sectionUpdated: [Int] = [],
        sectionMoved: [(source: Int, target: Int)] = [],
        elementDeleted: [ElementPath] = [],
        elementInserted: [ElementPath] = [],
        elementUpdated: [ElementPath] = [],
        elementMoved: [(source: ElementPath, target: ElementPath)] = []
        ) {
        self.data = data
        self.sectionDeleted = sectionDeleted
        self.sectionInserted = sectionInserted
        self.sectionUpdated = sectionUpdated
        self.sectionMoved = sectionMoved
        self.elementDeleted = elementDeleted
        self.elementInserted = elementInserted
        self.elementUpdated = elementUpdated
        self.elementMoved = elementMoved
    }
}

public extension Changeset {
    /// The number of section changes.
    @inlinable
    var sectionChangeCount: Int {
        return sectionDeleted.count
            + sectionInserted.count
            + sectionUpdated.count
            + sectionMoved.count
    }

    /// The number of element changes.
    @inlinable
    var elementChangeCount: Int {
        return elementDeleted.count
            + elementInserted.count
            + elementUpdated.count
            + elementMoved.count
    }

    /// The number of all changes.
    @inlinable
    var changeCount: Int {
        return sectionChangeCount + elementChangeCount
    }

    /// A Boolean value indicating whether has section changes.
    @inlinable
    var hasSectionChanges: Bool {
        return sectionChangeCount > 0
    }

    /// A Boolean value indicating whether has element changes.
    @inlinable
    var hasElementChanges: Bool {
        return elementChangeCount > 0
    }

    /// A Boolean value indicating whether has changes.
    @inlinable
    var hasChanges: Bool {
        return changeCount > 0
    }
}

extension Changeset: Equatable where Collection: Equatable {
    public static func == (lhs: Changeset, rhs: Changeset) -> Bool {
        return lhs.data == rhs.data
            && Set(lhs.sectionDeleted) == Set(rhs.sectionDeleted)
            && Set(lhs.sectionInserted) == Set(rhs.sectionInserted)
            && Set(lhs.sectionUpdated) == Set(rhs.sectionUpdated)
            && Set(lhs.sectionMoved.map(HashablePair.init)) == Set(rhs.sectionMoved.map(HashablePair.init))
            && Set(lhs.elementDeleted) == Set(rhs.elementDeleted)
            && Set(lhs.elementInserted) == Set(rhs.elementInserted)
            && Set(lhs.elementUpdated) == Set(rhs.elementUpdated)
            && Set(lhs.elementMoved.map(HashablePair.init)) == Set(rhs.elementMoved.map(HashablePair.init))
    }
}

extension Changeset: CustomDebugStringConvertible {
    public var debugDescription: String {
        guard !data.isEmpty || hasChanges else {
            return """
            Changeset(
                data: []
            )"
            """
        }

        var description = """
        Changeset(
            data: \(data.isEmpty ? "[]" : "[\n        \(data.map { "\($0)" }.joined(separator: ",\n").split(separator: "\n").joined(separator: "\n        "))\n    ]")
        """

        func appendDescription<T>(name: String, elements: [T]) {
            guard !elements.isEmpty else { return }

            description += ",\n    \(name): [\n        \(elements.map { "\($0)" }.joined(separator: ",\n").split(separator: "\n").joined(separator: "\n        "))\n    ]"
        }

        appendDescription(name: "sectionDeleted", elements: sectionDeleted)
        appendDescription(name: "sectionInserted", elements: sectionInserted)
        appendDescription(name: "sectionUpdated", elements: sectionUpdated)
        appendDescription(name: "sectionMoved", elements: sectionMoved)
        appendDescription(name: "elementDeleted", elements: elementDeleted)
        appendDescription(name: "elementInserted", elements: elementInserted)
        appendDescription(name: "elementUpdated", elements: elementUpdated)
        appendDescription(name: "elementMoved", elements: elementMoved)

        description += "\n)"
        return description
    }
}

private struct HashablePair<H: Hashable>: Hashable {
    let first: H
    let second: H
}
