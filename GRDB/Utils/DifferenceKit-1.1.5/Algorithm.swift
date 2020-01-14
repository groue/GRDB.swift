// swiftlint:disable cyclomatic_complexity

public extension StagedChangeset where Collection: RangeReplaceableCollection, Collection.Element: Differentiable {
    /// Creates a new `StagedChangeset` from the two collections.
    ///
    /// Calculate the differences between the collections using
    /// the algorithm optimized based on the Paul Heckel's diff algorithm.
    ///
    /// - Note: This algorithm can compute the differences at high performance with O(n) complexity.
    ///         However, not always calculates the shortest differences.
    ///
    /// - Note: If the elements with the same identifier duplicated, the algorithm calculates
    ///         the moves at best effort, and rest of the duplicates as insertion or deletion.
    ///
    /// - Note: The data and changes each changeset contains are represents the middle of whole the changes.
    ///         Each changes are from the previous stage.
    ///
    /// - Parameters:
    ///   - source: A source collection to calculate differences.
    ///   - target: A target collection to calculate differences.
    ///
    /// - Complexity: O(n)
    @inlinable
    init(source: Collection, target: Collection) {
        self.init(source: source, target: target, section: 0)
    }

    /// Creates a new `StagedChangeset` from the two collections.
    ///
    /// Calculate the differences between the collections using
    /// the algorithm optimized based on the Paul Heckel's diff algorithm.
    ///
    /// - Note: This algorithm can compute the differences at high performance with O(n) complexity.
    ///         However, not always calculates the shortest differences.
    ///
    /// - Note: If the elements with the same identifier duplicated, the algorithm calculates
    ///         the moves at best effort, and rest of the duplicates as insertion or deletion.
    ///
    /// - Note: The data and changes each changeset contains are represents the middle of whole the changes.
    ///         Each changes are from the previous stage.
    ///
    /// - Parameters:
    ///   - source: A source collection to calculate differences.
    ///   - target: A target collection to calculate differences.
    ///   - section: An Int value to use as section index (or offset) of element.
    ///
    /// - Complexity: O(n)
    @inlinable
    init(source: Collection, target: Collection, section: Int) {
        let sourceElements = ContiguousArray(source)
        let targetElements = ContiguousArray(target)

        // Return empty changesets if both are empty.
        if sourceElements.isEmpty && targetElements.isEmpty {
            self.init()
            return
        }

        // Return changesets that all deletions if source is not empty and target is empty.
        if !sourceElements.isEmpty && targetElements.isEmpty {
            self.init([Changeset(data: target, elementDeleted: sourceElements.indices.map { ElementPath(element: $0, section: section) })])
            return
        }

        // Return changesets that all insertions if source is empty and target is not empty.
        if sourceElements.isEmpty && !targetElements.isEmpty {
            self.init([Changeset(data: target, elementInserted: targetElements.indices.map { ElementPath(element: $0, section: section) })])
            return
        }

        var firstStageElements = ContiguousArray<Collection.Element>()
        var secondStageElements = ContiguousArray<Collection.Element>()

        let result = diff(
            source: sourceElements,
            target: targetElements,
            useTargetIndexForUpdated: false,
            mapIndex: { ElementPath(element: $0, section: section) },
            updatedElementsPointer: &firstStageElements,
            notDeletedElementsPointer: &secondStageElements
        )

        var changesets = ContiguousArray<Changeset<Collection>>()

        // The 1st stage changeset.
        // - Includes:
        //   - element updates
        if !result.updated.isEmpty {
            changesets.append(
                Changeset(
                    data: Collection(firstStageElements),
                    elementUpdated: result.updated
                )
            )
        }

        // The 2nd stage changeset.
        // - Includes:
        //   - element deletes
        if !result.deleted.isEmpty {
            changesets.append(
                Changeset(
                    data: Collection(secondStageElements),
                    elementDeleted: result.deleted
                )
            )
        }

        // The 3rd stage changeset.
        // - Includes:
        //   - element inserts
        //   - element moves
        if !result.inserted.isEmpty || !result.moved.isEmpty {
            changesets.append(
                Changeset(
                    data: target,
                    elementInserted: result.inserted,
                    elementMoved: result.moved
                )
            )
        }

        // Set the target to `data` of the last stage.
        if !changesets.isEmpty {
            let index = changesets.index(before: changesets.endIndex)
            changesets[index].data = target
        }

        self.init(changesets)
    }
}

public extension StagedChangeset where Collection: RangeReplaceableCollection, Collection.Element: DifferentiableSection {
    /// Creates a new `StagedChangeset` from the two sectioned collections.
    ///
    /// Calculate the differences between the collections using
    /// the algorithm optimized based on the Paul Heckel's diff algorithm.
    ///
    /// - Note: This algorithm can compute the differences at high performance with O(n) complexity.
    ///         However, not always calculates the shortest differences.
    ///
    /// - Note: If the elements with the same identifier duplicated, the algorithm calculates
    ///         the moves at best effort, and rest of the duplicates as insertion or deletion.
    ///
    /// - Note: The data and changes each changeset contains are represents the middle of whole the changes.
    ///         Each changes are from the previous stage.
    ///
    /// - Parameters:
    ///   - source: A source sectioned collection to calculate differences.
    ///   - target: A target sectioned collection to calculate differences.
    ///
    /// - Complexity: O(n)
    @inlinable
    init(source: Collection, target: Collection) {
        typealias Section = Collection.Element
        typealias SectionIdentifier = Collection.Element.DifferenceIdentifier
        typealias Element = Collection.Element.Collection.Element
        typealias ElementIdentifier = Collection.Element.Collection.Element.DifferenceIdentifier

        let sourceSections = ContiguousArray(source)
        let targetSections = ContiguousArray(target)

        let contiguousSourceSections = ContiguousArray(sourceSections.map { ContiguousArray($0.elements) })
        let contiguousTargetSections = ContiguousArray(targetSections.map { ContiguousArray($0.elements) })

        var firstStageSections = sourceSections
        var secondStageSections = ContiguousArray<Section>()
        var thirdStageSections = ContiguousArray<Section>()
        var fourthStageSections = ContiguousArray<Section>()

        var sourceElementTraces = contiguousSourceSections.map { section in
            ContiguousArray(repeating: Trace<ElementPath>(), count: section.count)
        }
        var targetElementReferences = contiguousTargetSections.map { section in
            ContiguousArray<ElementPath?>(repeating: nil, count: section.count)
        }

        let flattenSourceCount = contiguousSourceSections.reduce(into: 0) { $0 += $1.count }
        var flattenSourceIdentifiers = ContiguousArray<ElementIdentifier>()
        var flattenSourceElementPaths = ContiguousArray<ElementPath>()

        thirdStageSections.reserveCapacity(contiguousTargetSections.count)
        fourthStageSections.reserveCapacity(contiguousTargetSections.count)

        flattenSourceIdentifiers.reserveCapacity(flattenSourceCount)
        flattenSourceElementPaths.reserveCapacity(flattenSourceCount)

        // Calculate section differences.

        let sectionResult = diff(
            source: sourceSections,
            target: targetSections,
            useTargetIndexForUpdated: true,
            mapIndex: { $0 }
        )

        // Calculate element differences.

        var elementDeleted = [ElementPath]()
        var elementInserted = [ElementPath]()
        var elementUpdated = [ElementPath]()
        var elementMoved = [(source: ElementPath, target: ElementPath)]()

        for sourceSectionIndex in contiguousSourceSections.indices {
            for sourceElementIndex in contiguousSourceSections[sourceSectionIndex].indices {
                let sourceElementPath = ElementPath(element: sourceElementIndex, section: sourceSectionIndex)
                let sourceElement = contiguousSourceSections[sourceElementPath]
                flattenSourceIdentifiers.append(sourceElement.differenceIdentifier)
                flattenSourceElementPaths.append(sourceElementPath)
            }
        }

        flattenSourceIdentifiers.withUnsafeBufferPointer { bufferPointer in
            // The pointer and the table key are for optimization.
            var sourceOccurrencesTable = [TableKey<ElementIdentifier>: Occurrence](minimumCapacity: flattenSourceCount)

            // Track indices of elements found in flatten source collection into occurrences table.
            for flattenSourceIndex in flattenSourceIdentifiers.indices {
                let pointer = bufferPointer.baseAddress!.advanced(by: flattenSourceIndex)
                let key = TableKey(pointer: pointer)

                switch sourceOccurrencesTable[key] {
                case .none:
                    sourceOccurrencesTable[key] = .unique(index: flattenSourceIndex)

                case .unique(let otherIndex)?:
                    let reference = IndicesReference([otherIndex, flattenSourceIndex])
                    sourceOccurrencesTable[key] = .duplicate(reference: reference)

                case .duplicate(let reference)?:
                    reference.push(flattenSourceIndex)
                }
            }

            // Track target and source indices of the elements having same identifier.
            for targetSectionIndex in contiguousTargetSections.indices {
                let targetElements = contiguousTargetSections[targetSectionIndex]

                for targetElementIndex in targetElements.indices {
                    var targetIdentifier = targetElements[targetElementIndex].differenceIdentifier
                    let key = TableKey(pointer: &targetIdentifier)

                    switch sourceOccurrencesTable[key] {
                    case .none:
                        break

                    case .unique(let flattenSourceIndex)?:
                        let sourceElementPath = flattenSourceElementPaths[flattenSourceIndex]
                        let targetElementPath = ElementPath(element: targetElementIndex, section: targetSectionIndex)

                        if case .none = sourceElementTraces[sourceElementPath].reference {
                            targetElementReferences[targetElementPath] = sourceElementPath
                            sourceElementTraces[sourceElementPath].reference = targetElementPath
                        }

                    case .duplicate(let reference)?:
                        if let flattenSourceIndex = reference.next() {
                            let sourceElementPath = flattenSourceElementPaths[flattenSourceIndex]
                            let targetElementPath = ElementPath(element: targetElementIndex, section: targetSectionIndex)
                            targetElementReferences[targetElementPath] = sourceElementPath
                            sourceElementTraces[sourceElementPath].reference = targetElementPath
                        }
                    }
                }
            }
        }

        // Track element deletes.
        for sourceSectionIndex in contiguousSourceSections.indices {
            let sourceSection = sourceSections[sourceSectionIndex]
            let sourceElements = contiguousSourceSections[sourceSectionIndex]
            var firstStageElements = sourceElements

            // Should not track element deletes in the deleted section.
            if case .some = sectionResult.sourceTraces[sourceSectionIndex].reference {
                var offsetByDelete = 0

                var secondStageElements = ContiguousArray<Element>()

                for sourceElementIndex in sourceElements.indices {
                    let sourceElementPath = ElementPath(element: sourceElementIndex, section: sourceSectionIndex)

                    sourceElementTraces[sourceElementPath].deleteOffset = offsetByDelete

                    // Track element deletes if target section is tracked as inserts.
                    if let targetElementPath = sourceElementTraces[sourceElementPath].reference,
                        case .some = sectionResult.targetReferences[targetElementPath.section] {
                        let targetElement = contiguousTargetSections[targetElementPath]
                        firstStageElements[sourceElementIndex] = targetElement
                        secondStageElements.append(targetElement)
                        continue
                    }

                    elementDeleted.append(sourceElementPath)
                    sourceElementTraces[sourceElementPath].isTracked = true
                    offsetByDelete += 1
                }

                let secondStageSection = Section(source: sourceSection, elements: secondStageElements)
                secondStageSections.append(secondStageSection)

            }

            let firstStageSection = Section(source: sourceSection, elements: firstStageElements)
            firstStageSections[sourceSectionIndex] = firstStageSection
        }

        // Track element updates / moves / inserts.
        for targetSectionIndex in contiguousTargetSections.indices {
            // Should not track element updates / moves / inserts in the inserted section.
            guard let sourceSectionIndex = sectionResult.targetReferences[targetSectionIndex] else {
                thirdStageSections.append(targetSections[targetSectionIndex])
                fourthStageSections.append(targetSections[targetSectionIndex])
                continue
            }

            var untrackedSourceIndex: Int? = 0
            let targetElements = contiguousTargetSections[targetSectionIndex]

            let sectionDeleteOffset = sectionResult.sourceTraces[sourceSectionIndex].deleteOffset

            let thirdStageSection = secondStageSections[sourceSectionIndex - sectionDeleteOffset]
            thirdStageSections.append(thirdStageSection)

            var fourthStageElements = ContiguousArray<Element>()
            fourthStageElements.reserveCapacity(targetElements.count)

            for targetElementIndex in targetElements.indices {
                untrackedSourceIndex = untrackedSourceIndex.flatMap { index in
                    sourceElementTraces[sourceSectionIndex].suffix(from: index).firstIndex { !$0.isTracked }
                }

                let targetElementPath = ElementPath(element: targetElementIndex, section: targetSectionIndex)
                let targetElement = contiguousTargetSections[targetElementPath]

                // Track element inserts if source section is tracked as deletes.
                guard let sourceElementPath = targetElementReferences[targetElementPath],
                    let movedSourceSectionIndex = sectionResult.sourceTraces[sourceElementPath.section].reference else {
                        fourthStageElements.append(targetElement)
                        elementInserted.append(targetElementPath)
                        continue
                }

                sourceElementTraces[sourceElementPath].isTracked = true

                let sourceElement = contiguousSourceSections[sourceElementPath]
                fourthStageElements.append(targetElement)

                if !targetElement.isContentEqual(to: sourceElement) {
                    elementUpdated.append(sourceElementPath)
                }

                if sourceElementPath.section != sourceSectionIndex || sourceElementPath.element != untrackedSourceIndex {
                    let deleteOffset = sourceElementTraces[sourceElementPath].deleteOffset
                    let moveSourceElementPath = ElementPath(element: sourceElementPath.element - deleteOffset, section: movedSourceSectionIndex)
                    elementMoved.append((source: moveSourceElementPath, target: targetElementPath))
                }
            }

            let fourthStageSection = Section(source: thirdStageSection, elements: fourthStageElements)
            fourthStageSections.append(fourthStageSection)
        }

        var changesets = ContiguousArray<Changeset<Collection>>()

        // The 1st stage changeset.
        // - Includes:
        //   - element updates
        if !elementUpdated.isEmpty {
            changesets.append(
                Changeset(
                    data: Collection(firstStageSections),
                    elementUpdated: elementUpdated
                )
            )
        }

        // The 2nd stage changeset.
        // - Includes:
        //   - section deletes
        //   - element deletes
        if !sectionResult.deleted.isEmpty || !elementDeleted.isEmpty {
            changesets.append(
                Changeset(
                    data: Collection(secondStageSections),
                    sectionDeleted: sectionResult.deleted,
                    elementDeleted: elementDeleted
                )
            )
        }

        // The 3rd stage changeset.
        // - Includes:
        //   - section inserts
        //   - section moves
        if !sectionResult.inserted.isEmpty || !sectionResult.moved.isEmpty {
            changesets.append(
                Changeset(
                    data: Collection(thirdStageSections),
                    sectionInserted: sectionResult.inserted,
                    sectionMoved: sectionResult.moved
                )
            )
        }

        // The 4th stage changeset.
        // - Includes:
        //   - element inserts
        //   - element moves
        if !elementInserted.isEmpty || !elementMoved.isEmpty {
            changesets.append(
                Changeset(
                    data: Collection(fourthStageSections),
                    elementInserted: elementInserted,
                    elementMoved: elementMoved
                )
            )
        }

        // The 5th stage changeset.
        // - Includes:
        //   - section updates
        if !sectionResult.updated.isEmpty {
            changesets.append(
                Changeset(
                    data: target,
                    sectionUpdated: sectionResult.updated
                )
            )
        }

        // Set the target to `data` of the last stage.
        if !changesets.isEmpty {
            let index = changesets.index(before: changesets.endIndex)
            changesets[index].data = target
        }

        self.init(changesets)
    }
}

/// The shared algorithm to calculate diffs between two linear collections.
@inlinable
@discardableResult
internal func diff<E: Differentiable, I>(
    source: ContiguousArray<E>,
    target: ContiguousArray<E>,
    useTargetIndexForUpdated: Bool,
    mapIndex: (Int) -> I,
    updatedElementsPointer: UnsafeMutablePointer<ContiguousArray<E>>? = nil,
    notDeletedElementsPointer: UnsafeMutablePointer<ContiguousArray<E>>? = nil
    ) -> DiffResult<I> {
    var deleted = [I]()
    var inserted = [I]()
    var updated = [I]()
    var moved = [(source: I, target: I)]()

    var sourceTraces = ContiguousArray<Trace<Int>>()
    var sourceIdentifiers = ContiguousArray<E.DifferenceIdentifier>()
    var targetReferences = ContiguousArray<Int?>(repeating: nil, count: target.count)

    sourceTraces.reserveCapacity(source.count)
    sourceIdentifiers.reserveCapacity(source.count)

    for sourceElement in source {
        sourceTraces.append(Trace())
        sourceIdentifiers.append(sourceElement.differenceIdentifier)
    }

    sourceIdentifiers.withUnsafeBufferPointer { bufferPointer in
        // The pointer and the table key are for optimization.
        var sourceOccurrencesTable = [TableKey<E.DifferenceIdentifier>: Occurrence](minimumCapacity: source.count)

        // Track indices of elements found in source collection into occurrences table.
        for sourceIndex in sourceIdentifiers.indices {
            let pointer = bufferPointer.baseAddress!.advanced(by: sourceIndex)
            let key = TableKey(pointer: pointer)

            switch sourceOccurrencesTable[key] {
            case .none:
                sourceOccurrencesTable[key] = .unique(index: sourceIndex)

            case .unique(let otherIndex)?:
                let reference = IndicesReference([otherIndex, sourceIndex])
                sourceOccurrencesTable[key] = .duplicate(reference: reference)

            case .duplicate(let reference)?:
                reference.push(sourceIndex)
            }
        }

        // Track target and source indices of the elements having same identifier.
        for targetIndex in target.indices {
            var targetIdentifier = target[targetIndex].differenceIdentifier
            let key = TableKey(pointer: &targetIdentifier)

            switch sourceOccurrencesTable[key] {
            case .none:
                break

            case .unique(let sourceIndex)?:
                if case .none = sourceTraces[sourceIndex].reference {
                    targetReferences[targetIndex] = sourceIndex
                    sourceTraces[sourceIndex].reference = targetIndex
                }

            case .duplicate(let reference)?:
                if let sourceIndex = reference.next() {
                    targetReferences[targetIndex] = sourceIndex
                    sourceTraces[sourceIndex].reference = targetIndex
                }
            }
        }
    }

    var offsetByDelete = 0
    var untrackedSourceIndex: Int? = 0

    // Track deletes.
    for sourceIndex in source.indices {
        sourceTraces[sourceIndex].deleteOffset = offsetByDelete

        if let targetIndex = sourceTraces[sourceIndex].reference {
            let targetElement = target[targetIndex]
            updatedElementsPointer?.pointee.append(targetElement)
            notDeletedElementsPointer?.pointee.append(targetElement)
        }
        else {
            let sourceElement = source[sourceIndex]
            deleted.append(mapIndex(sourceIndex))
            sourceTraces[sourceIndex].isTracked = true
            offsetByDelete += 1
            updatedElementsPointer?.pointee.append(sourceElement)
        }
    }

    // Track updates / moves / inserts.
    for targetIndex in target.indices {
        untrackedSourceIndex = untrackedSourceIndex.flatMap { index in
            sourceTraces.suffix(from: index).firstIndex { !$0.isTracked }
        }

        if let sourceIndex = targetReferences[targetIndex] {
            sourceTraces[sourceIndex].isTracked = true

            let sourceElement = source[sourceIndex]
            let targetElement = target[targetIndex]

            if !targetElement.isContentEqual(to: sourceElement) {
                updated.append(mapIndex(useTargetIndexForUpdated ? targetIndex : sourceIndex))
            }

            if sourceIndex != untrackedSourceIndex {
                let deleteOffset = sourceTraces[sourceIndex].deleteOffset
                moved.append((source: mapIndex(sourceIndex - deleteOffset), target: mapIndex(targetIndex)))
            }
        }
        else {
            inserted.append(mapIndex(targetIndex))
        }
    }

    return DiffResult(
        deleted: deleted,
        inserted: inserted,
        updated: updated,
        moved: moved,
        sourceTraces: sourceTraces,
        targetReferences: targetReferences
    )
}

/// A set of changes and metadata as a result of calculating differences in linear collection.
@usableFromInline
internal struct DiffResult<Index> {
    @usableFromInline
    internal let deleted: [Index]
    @usableFromInline
    internal let inserted: [Index]
    @usableFromInline
    internal let updated: [Index]
    @usableFromInline
    internal let moved: [(source: Index, target: Index)]
    @usableFromInline
    internal let sourceTraces: ContiguousArray<Trace<Int>>
    @usableFromInline
    internal let targetReferences: ContiguousArray<Int?>

    @usableFromInline
    internal init(
        deleted: [Index] = [],
        inserted: [Index] = [],
        updated: [Index] = [],
        moved: [(source: Index, target: Index)] = [],
        sourceTraces: ContiguousArray<Trace<Int>>,
        targetReferences: ContiguousArray<Int?>
        ) {
        self.deleted = deleted
        self.inserted = inserted
        self.updated = updated
        self.moved = moved
        self.sourceTraces = sourceTraces
        self.targetReferences = targetReferences
    }
}

/// A set of informations in middle of difference calculation.
@usableFromInline
internal struct Trace<Index> {
    @usableFromInline
    internal var reference: Index?
    @usableFromInline
    internal var deleteOffset = 0
    @usableFromInline
    internal var isTracked = false

    @usableFromInline
    internal init() {}
}

/// The occurrences of element.
@usableFromInline
internal enum Occurrence {
    case unique(index: Int)
    case duplicate(reference: IndicesReference)
}

/// A mutable reference to indices of elements.
@usableFromInline
internal final class IndicesReference {
    @usableFromInline
    internal var indices: ContiguousArray<Int>
    @usableFromInline
    internal var position = 0

    @usableFromInline
    internal init(_ indices: ContiguousArray<Int>) {
        self.indices = indices
    }

    @inlinable
    internal func push(_ index: Int) {
        indices.append(index)
    }

    @inlinable
    internal func next() -> Int? {
        guard position < indices.endIndex else {
            return nil
        }
        defer { position += 1 }
        return indices[position]
    }
}

/// Dictionary key using UnsafePointer for performance optimization.
@usableFromInline
internal struct TableKey<T: Hashable>: Hashable {
    @usableFromInline
    internal let pointeeHashValue: Int
    @usableFromInline
    internal let pointer: UnsafePointer<T>

    @usableFromInline
    internal init(pointer: UnsafePointer<T>) {
        self.pointeeHashValue = pointer.pointee.hashValue
        self.pointer = pointer
    }

    @inlinable
    internal static func == (lhs: TableKey, rhs: TableKey) -> Bool {
        return lhs.pointeeHashValue == rhs.pointeeHashValue
            && (lhs.pointer.distance(to: rhs.pointer) == 0 || lhs.pointer.pointee == rhs.pointer.pointee)
    }

    @inlinable
    internal func hash(into hasher: inout Hasher) {
        hasher.combine(pointeeHashValue)
    }
}

internal extension MutableCollection where Element: MutableCollection, Index == Int, Element.Index == Int {
    @inlinable
    subscript(path: ElementPath) -> Element.Element {
        get { return self[path.section][path.element] }
        set { self[path.section][path.element] = newValue }
    }
}
