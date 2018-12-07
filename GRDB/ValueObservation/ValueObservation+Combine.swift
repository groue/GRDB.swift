extension ValueObservation where Reducer == Void {
    public static func combine<R1: ValueReducer, R2: ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>)
        -> ValueObservation<AnyValueReducer<
        (R1.Fetched, R2.Fetched),
        (R1.Value, R2.Value)>>
    {
        return ValueObservation<AnyValueReducer<
            (R1.Fetched, R2.Fetched),
            (R1.Value, R2.Value)>>(
                tracking: { try DatabaseRegion.union(
                    o1.observedRegion($0),
                    o2.observedRegion($0)) },
                reducer: { try _combine(
                    o1.makeReducer($0),
                    o2.makeReducer($0)) })
    }
    
    public static func combine<R1: ValueReducer, R2: ValueReducer, R3: ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>)
        -> ValueObservation<AnyValueReducer<
        (R1.Fetched, R2.Fetched, R3.Fetched),
        (R1.Value, R2.Value, R3.Value)>>
    {
        return ValueObservation<AnyValueReducer<
            (R1.Fetched, R2.Fetched, R3.Fetched),
            (R1.Value, R2.Value, R3.Value)>>(
                tracking: { try DatabaseRegion.union(
                    o1.observedRegion($0),
                    o2.observedRegion($0),
                    o3.observedRegion($0)) },
                reducer: { try _combine(
                    o1.makeReducer($0),
                    o2.makeReducer($0),
                    o3.makeReducer($0)) })
    }
    
    public static func combine<R1: ValueReducer, R2: ValueReducer, R3: ValueReducer, R4: ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>)
        -> ValueObservation<AnyValueReducer<
        (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched),
        (R1.Value, R2.Value, R3.Value, R4.Value)>>
    {
        return ValueObservation<AnyValueReducer<
            (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched),
            (R1.Value, R2.Value, R3.Value, R4.Value)>>(
                tracking: { try DatabaseRegion.union(
                    o1.observedRegion($0),
                    o2.observedRegion($0),
                    o3.observedRegion($0),
                    o4.observedRegion($0)) },
                reducer: { try _combine(
                    o1.makeReducer($0),
                    o2.makeReducer($0),
                    o3.makeReducer($0),
                    o4.makeReducer($0)) })
    }
    
    public static func combine<R1: ValueReducer, R2: ValueReducer, R3: ValueReducer, R4: ValueReducer, R5: ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>)
        -> ValueObservation<AnyValueReducer<
        (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched, R5.Fetched),
        (R1.Value, R2.Value, R3.Value, R4.Value, R5.Value)>>
    {
        return ValueObservation<AnyValueReducer<
            (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched, R5.Fetched),
            (R1.Value, R2.Value, R3.Value, R4.Value, R5.Value)>>(
                tracking: { try DatabaseRegion.union(
                    o1.observedRegion($0),
                    o2.observedRegion($0),
                    o3.observedRegion($0),
                    o4.observedRegion($0),
                    o5.observedRegion($0)) },
                reducer: { try _combine(
                    o1.makeReducer($0),
                    o2.makeReducer($0),
                    o3.makeReducer($0),
                    o4.makeReducer($0),
                    o5.makeReducer($0)) })
    }
}

private func _combine<R1: ValueReducer, R2: ValueReducer>(
    _ r1: R1,
    _ r2: R2)
    -> AnyValueReducer<
    (R1.Fetched, R2.Fetched),
    (R1.Value, R2.Value)>
{
    var r1 = r1
    var r2 = r2
    var prev1: R1.Value?
    var prev2: R2.Value?
    func fetch(db: Database) throws -> (R1.Fetched, R2.Fetched) {
        return try (
            r1.fetch(db),
            r2.fetch(db))
    }
    func value(tuple: (R1.Fetched, R2.Fetched)) -> (R1.Value, R2.Value)? {
        let v1 = r1.value(tuple.0)
        let v2 = r2.value(tuple.1)
        defer {
            if let v1 = v1 { prev1 = v1 }
            if let v2 = v2 { prev2 = v2 }
        }
        if  v1 != nil || v2 != nil,
            let c1 = v1 ?? prev1,
            let c2 = v2 ?? prev2
        {
            return (c1, c2)
        } else {
            return nil
        }
    }
    return AnyValueReducer(fetch: fetch, value: value)
}

private func _combine<R1: ValueReducer, R2: ValueReducer, R3: ValueReducer>(
    _ r1: R1,
    _ r2: R2,
    _ r3: R3)
    -> AnyValueReducer<
    (R1.Fetched, R2.Fetched, R3.Fetched),
    (R1.Value, R2.Value, R3.Value)>
{
    var r1 = r1
    var r2 = r2
    var r3 = r3
    var prev1: R1.Value?
    var prev2: R2.Value?
    var prev3: R3.Value?
    func fetch(db: Database) throws -> (R1.Fetched, R2.Fetched, R3.Fetched) {
        return try (
            r1.fetch(db),
            r2.fetch(db),
            r3.fetch(db))
    }
    func value(tuple: (R1.Fetched, R2.Fetched, R3.Fetched)) -> (R1.Value, R2.Value, R3.Value)? {
        let v1 = r1.value(tuple.0)
        let v2 = r2.value(tuple.1)
        let v3 = r3.value(tuple.2)
        defer {
            if let v1 = v1 { prev1 = v1 }
            if let v2 = v2 { prev2 = v2 }
            if let v3 = v3 { prev3 = v3 }
        }
        if  v1 != nil || v2 != nil || v3 != nil,
            let c1 = v1 ?? prev1,
            let c2 = v2 ?? prev2,
            let c3 = v3 ?? prev3
        {
            return (c1, c2, c3)
        } else {
            return nil
        }
    }
    return AnyValueReducer(fetch: fetch, value: value)
}

private func _combine<R1: ValueReducer, R2: ValueReducer, R3: ValueReducer, R4: ValueReducer>(
    _ r1: R1,
    _ r2: R2,
    _ r3: R3,
    _ r4: R4)
    -> AnyValueReducer<
    (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched),
    (R1.Value, R2.Value, R3.Value, R4.Value)>
{
    var r1 = r1
    var r2 = r2
    var r3 = r3
    var r4 = r4
    var prev1: R1.Value?
    var prev2: R2.Value?
    var prev3: R3.Value?
    var prev4: R4.Value?
    func fetch(db: Database) throws -> (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched) {
        return try (
            r1.fetch(db),
            r2.fetch(db),
            r3.fetch(db),
            r4.fetch(db))
    }
    func value(tuple: (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched)) -> (R1.Value, R2.Value, R3.Value, R4.Value)? {
        let v1 = r1.value(tuple.0)
        let v2 = r2.value(tuple.1)
        let v3 = r3.value(tuple.2)
        let v4 = r4.value(tuple.3)
        defer {
            if let v1 = v1 { prev1 = v1 }
            if let v2 = v2 { prev2 = v2 }
            if let v3 = v3 { prev3 = v3 }
            if let v4 = v4 { prev4 = v4 }
        }
        if  v1 != nil || v2 != nil || v3 != nil || v4 != nil,
            let c1 = v1 ?? prev1,
            let c2 = v2 ?? prev2,
            let c3 = v3 ?? prev3,
            let c4 = v4 ?? prev4
        {
            return (c1, c2, c3, c4)
        } else {
            return nil
        }
    }
    return AnyValueReducer(fetch: fetch, value: value)
}

private func _combine<R1: ValueReducer, R2: ValueReducer, R3: ValueReducer, R4: ValueReducer, R5: ValueReducer>(
    _ r1: R1,
    _ r2: R2,
    _ r3: R3,
    _ r4: R4,
    _ r5: R5)
    -> AnyValueReducer<
    (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched, R5.Fetched),
    (R1.Value, R2.Value, R3.Value, R4.Value, R5.Value)>
{
    var r1 = r1
    var r2 = r2
    var r3 = r3
    var r4 = r4
    var r5 = r5
    var prev1: R1.Value?
    var prev2: R2.Value?
    var prev3: R3.Value?
    var prev4: R4.Value?
    var prev5: R5.Value?
    func fetch(db: Database) throws -> (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched, R5.Fetched) {
        return try (
            r1.fetch(db),
            r2.fetch(db),
            r3.fetch(db),
            r4.fetch(db),
            r5.fetch(db))
    }
    func value(tuple: (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched, R5.Fetched)) -> (R1.Value, R2.Value, R3.Value, R4.Value, R5.Value)? {
        let v1 = r1.value(tuple.0)
        let v2 = r2.value(tuple.1)
        let v3 = r3.value(tuple.2)
        let v4 = r4.value(tuple.3)
        let v5 = r5.value(tuple.4)
        defer {
            if let v1 = v1 { prev1 = v1 }
            if let v2 = v2 { prev2 = v2 }
            if let v3 = v3 { prev3 = v3 }
            if let v4 = v4 { prev4 = v4 }
            if let v5 = v5 { prev5 = v5 }
        }
        if  v1 != nil || v2 != nil || v3 != nil || v4 != nil || v5 != nil,
            let c1 = v1 ?? prev1,
            let c2 = v2 ?? prev2,
            let c3 = v3 ?? prev3,
            let c4 = v4 ?? prev4,
            let c5 = v5 ?? prev5
        {
            return (c1, c2, c3, c4, c5)
        } else {
            return nil
        }
    }
    return AnyValueReducer(fetch: fetch, value: value)
}
