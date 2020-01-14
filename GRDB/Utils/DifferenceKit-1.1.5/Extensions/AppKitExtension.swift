#if os(macOS)
import AppKit

public extension NSTableView {
    /// Applies multiple animated updates in stages using `StagedChangeset`.
    ///
    /// - Note: There are combination of changes that crash when applied simultaneously in `performBatchUpdates`.
    ///         Assumes that `StagedChangeset` has a minimum staged changesets to avoid it.
    ///         The data of the data-source needs to be updated synchronously before `performBatchUpdates` in every stages.
    ///
    /// - Parameters:
    ///   - stagedChangeset: A staged set of changes.
    ///   - animation: An option to animate the updates.
    ///   - interrupt: A closure that takes an changeset as its argument and returns `true` if the animated
    ///                updates should be stopped and performed reloadData. Default is nil.
    ///   - setData: A closure that takes the collection as a parameter.
    ///              The collection should be set to data-source of NSTableView.

    func reload<C>(
        using stagedChangeset: StagedChangeset<C>,
        with animation: @autoclosure () -> NSTableView.AnimationOptions,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        setData: (C) -> Void
        ) {
        reload(
            using: stagedChangeset,
            deleteRowsAnimation: animation(),
            insertRowsAnimation: animation(),
            reloadRowsAnimation: animation(),
            interrupt: interrupt,
            setData: setData
        )
    }

    /// Applies multiple animated updates in stages using `StagedChangeset`.
    ///
    /// - Note: There are combination of changes that crash when applied simultaneously in `performBatchUpdates`.
    ///         Assumes that `StagedChangeset` has a minimum staged changesets to avoid it.
    ///         The data of the data-source needs to be updated synchronously before `performBatchUpdates` in every stages.
    ///
    /// - Parameters:
    ///   - stagedChangeset: A staged set of changes.
    ///   - deleteRowsAnimation: An option to animate the row deletion.
    ///   - insertRowsAnimation: An option to animate the row insertion.
    ///   - reloadRowsAnimation: An option to animate the row reload.
    ///   - interrupt: A closure that takes an changeset as its argument and returns `true` if the animated
    ///                updates should be stopped and performed reloadData. Default is nil.
    ///   - setData: A closure that takes the collection as a parameter.
    ///              The collection should be set to data-source of NSTableView.
    func reload<C>(
        using stagedChangeset: StagedChangeset<C>,
        deleteRowsAnimation: @autoclosure () -> NSTableView.AnimationOptions,
        insertRowsAnimation: @autoclosure () -> NSTableView.AnimationOptions,
        reloadRowsAnimation: @autoclosure () -> NSTableView.AnimationOptions,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        setData: (C) -> Void
        ) {
        if case .none = window, let data = stagedChangeset.last?.data {
            setData(data)
            return reloadData()
        }

        for changeset in stagedChangeset {
            if let interrupt = interrupt, interrupt(changeset), let data = stagedChangeset.last?.data {
                setData(data)
                return reloadData()
            }

            beginUpdates()
            setData(changeset.data)

            if !changeset.elementDeleted.isEmpty {
                removeRows(at: IndexSet(changeset.elementDeleted.map { $0.element }), withAnimation: deleteRowsAnimation())
            }

            if !changeset.elementInserted.isEmpty {
                insertRows(at: IndexSet(changeset.elementInserted.map { $0.element }), withAnimation: insertRowsAnimation())
            }

            if !changeset.elementUpdated.isEmpty {
                reloadData(forRowIndexes: IndexSet(changeset.elementUpdated.map { $0.element }), columnIndexes: IndexSet(changeset.elementUpdated.map { $0.section }))
            }

            for (source, target) in changeset.elementMoved {
                moveRow(at: source.element, to: target.element)
            }

            endUpdates()
        }
    }
}

@available(macOS 10.11, *)
public extension NSCollectionView {
    /// Applies multiple animated updates in stages using `StagedChangeset`.
    ///
    /// - Note: There are combination of changes that crash when applied simultaneously in `performBatchUpdates`.
    ///         Assumes that `StagedChangeset` has a minimum staged changesets to avoid it.
    ///         The data of the data-source needs to be updated synchronously before `performBatchUpdates` in every stages.
    ///
    /// - Parameters:
    ///   - stagedChangeset: A staged set of changes.
    ///   - interrupt: A closure that takes an changeset as its argument and returns `true` if the animated
    ///                updates should be stopped and performed reloadData. Default is nil.
    ///   - setData: A closure that takes the collection as a parameter.
    ///              The collection should be set to data-source of NSCollectionView.
    func reload<C>(
        using stagedChangeset: StagedChangeset<C>,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        setData: (C) -> Void
        ) {
        if case .none = window, let data = stagedChangeset.last?.data {
            setData(data)
            return reloadData()
        }

        for changeset in stagedChangeset {
            if let interrupt = interrupt, interrupt(changeset), let data = stagedChangeset.last?.data {
                setData(data)
                return reloadData()
            }

            animator().performBatchUpdates({
                setData(changeset.data)

                if !changeset.elementDeleted.isEmpty {
                    deleteItems(at: Set(changeset.elementDeleted.map { IndexPath(item: $0.element, section: $0.section) }))
                }

                if !changeset.elementInserted.isEmpty {
                    insertItems(at: Set(changeset.elementInserted.map { IndexPath(item: $0.element, section: $0.section) }))
                }

                if !changeset.elementUpdated.isEmpty {
                    reloadItems(at: Set(changeset.elementUpdated.map { IndexPath(item: $0.element, section: $0.section) }))
                }

                for (source, target) in changeset.elementMoved {
                    moveItem(at: IndexPath(item: source.element, section: source.section), to: IndexPath(item: target.element, section: target.section))
                }
            })
        }
    }
}
#endif
