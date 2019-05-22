extension QueryInterfaceRequest where RowDecoder: TableRecord {
    // MARK: - Associations
    
    /// Creates a request that prefetches an association.
    public func including<A: AssociationToMany>(all association: A) -> QueryInterfaceRequest where A.OriginRowDecoder == RowDecoder {
        return mapQuery {
            $0.mapRelation {
                $0.including(all: association.sqlAssociation)
            }
        }
    }

    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned request does not
    /// require that the associated database table contains a matching row.
    public func including<A: Association>(optional association: A) -> QueryInterfaceRequest where A.OriginRowDecoder == RowDecoder {
        return mapQuery {
            $0.mapRelation {
                $0.including(optional: association.sqlAssociation)
            }
        }
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned request requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A) -> QueryInterfaceRequest where A.OriginRowDecoder == RowDecoder {
        return mapQuery {
            $0.mapRelation {
                $0.including(required: association.sqlAssociation)
            }
        }
    }
    
    /// Creates a request that joins an association. The columns of the
    /// associated record are not selected. The returned request does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A) -> QueryInterfaceRequest where A.OriginRowDecoder == RowDecoder {
        return mapQuery {
            $0.mapRelation {
                $0.joining(optional: association.sqlAssociation)
            }
        }
    }
    
    /// Creates a request that joins an association. The columns of the
    /// associated record are not selected. The returned request requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A) -> QueryInterfaceRequest where A.OriginRowDecoder == RowDecoder {
        return mapQuery {
            $0.mapRelation {
                $0.joining(required: association.sqlAssociation)
            }
        }
    }
    
    // MARK: - Association Aggregates
    
    private func annotated(with aggregate: AssociationAggregate<RowDecoder>) -> QueryInterfaceRequest {
        let (request, expression) = aggregate.prepare(self)
        if let alias = aggregate.alias {
            return request.annotated(with: [expression.aliased(alias)])
        } else {
            return request.annotated(with: [expression])
        }
    }
    
    /// Creates a request which appends *aggregates* to the current selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.all()
    ///     request = request.annotated(with: Player.books.count)
    public func annotated(with aggregates: AssociationAggregate<RowDecoder>...) -> QueryInterfaceRequest {
        return annotated(with: aggregates)
    }

    /// Creates a request which appends *aggregates* to the current selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.all()
    ///     request = request.annotated(with: [Player.books.count])
    public func annotated(with aggregates: [AssociationAggregate<RowDecoder>]) -> QueryInterfaceRequest {
        return aggregates.reduce(self) { request, aggregate in
            request.annotated(with: aggregate)
        }
    }
    
    /// Creates a request which appends the provided aggregate *predicate* to
    /// the eventual set of already applied predicates.
    ///
    ///     // SELECT player.*
    ///     // FROM player LEFT JOIN book ...
    ///     // HAVING COUNT(DISTINCT book.rowid) = 0
    ///     var request = Player.all()
    ///     request = request.having(Player.books.isEmpty)
    public func having(_ predicate: AssociationAggregate<RowDecoder>) -> QueryInterfaceRequest {
        let (request, expression) = predicate.prepare(self)
        return request.having(expression)
    }
}
