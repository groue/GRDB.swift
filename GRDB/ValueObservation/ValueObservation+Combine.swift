// MARK: - Combine 2 Reducers

public struct CombinedValueReducer2<
    Base1: ValueReducer,
    Base2: ValueReducer>: ValueReducer
{
    public typealias Fetched = (Base1.Fetched, Base2.Fetched)
    public typealias Value = (Base1.Value, Base2.Value)
    var base1: Base1
    var base2: Base2
    private var prev1: Base1.Value? = nil
    private var prev2: Base2.Value? = nil
    
    init(base1: Base1, base2: Base2) {
        self.base1 = base1
        self.base2 = base2
    }
    
    public func fetch(_ db: Database) throws -> Fetched {
        return try (
            base1.fetch(db),
            base2.fetch(db))
    }
    
    mutating public func value(_ fetched: Fetched) -> Value? {
        let v1 = base1.value(fetched.0)
        let v2 = base2.value(fetched.1)
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
}

extension CombinedValueReducer2: ImmediateValueReducer where
    Base1: ImmediateValueReducer,
    Base2: ImmediateValueReducer
{ }

extension ValueObservation where Reducer == Void {
    public static func combine<R1: ValueReducer, R2: ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>)
        -> ValueObservation<CombinedValueReducer2<R1, R2>>
    {
        return ValueObservation<CombinedValueReducer2<R1, R2>>(
            tracking: { try DatabaseRegion.union(
                o1.observedRegion($0),
                o2.observedRegion($0)) },
            reducer: { try CombinedValueReducer2(
                base1: o1.makeReducer($0),
                base2: o2.makeReducer($0)) })
    }
}

// MARK: - Combine 3 Reducers

public struct CombinedValueReducer3<
    Base1: ValueReducer,
    Base2: ValueReducer,
    Base3: ValueReducer>: ValueReducer
{
    public typealias Fetched = (Base1.Fetched, Base2.Fetched, Base3.Fetched)
    public typealias Value = (Base1.Value, Base2.Value, Base3.Value)
    var base1: Base1
    var base2: Base2
    var base3: Base3
    private var prev1: Base1.Value? = nil
    private var prev2: Base2.Value? = nil
    private var prev3: Base3.Value? = nil

    init(base1: Base1, base2: Base2, base3: Base3) {
        self.base1 = base1
        self.base2 = base2
        self.base3 = base3
    }
    
    public func fetch(_ db: Database) throws -> Fetched {
        return try (
            base1.fetch(db),
            base2.fetch(db),
            base3.fetch(db))
    }
    
    mutating public func value(_ fetched: Fetched) -> Value? {
        let v1 = base1.value(fetched.0)
        let v2 = base2.value(fetched.1)
        let v3 = base3.value(fetched.2)
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
}

extension CombinedValueReducer3: ImmediateValueReducer where
    Base1: ImmediateValueReducer,
    Base2: ImmediateValueReducer,
    Base3: ImmediateValueReducer
{ }

extension ValueObservation where Reducer == Void {
    public static func combine<R1: ValueReducer, R2: ValueReducer, R3: ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>)
        -> ValueObservation<CombinedValueReducer3<R1, R2, R3>>
    {
        return ValueObservation<CombinedValueReducer3<R1, R2, R3>>(
            tracking: { try DatabaseRegion.union(
                o1.observedRegion($0),
                o2.observedRegion($0),
                o3.observedRegion($0)) },
            reducer: { try CombinedValueReducer3(
                base1: o1.makeReducer($0),
                base2: o2.makeReducer($0),
                base3: o3.makeReducer($0)) })
    }
}

// MARK: - Combine 4 Reducers

public struct CombinedValueReducer4<
    Base1: ValueReducer,
    Base2: ValueReducer,
    Base3: ValueReducer,
    Base4: ValueReducer>: ValueReducer
{
    public typealias Fetched = (Base1.Fetched, Base2.Fetched, Base3.Fetched, Base4.Fetched)
    public typealias Value = (Base1.Value, Base2.Value, Base3.Value, Base4.Value)
    var base1: Base1
    var base2: Base2
    var base3: Base3
    var base4: Base4
    private var prev1: Base1.Value? = nil
    private var prev2: Base2.Value? = nil
    private var prev3: Base3.Value? = nil
    private var prev4: Base4.Value? = nil

    init(base1: Base1, base2: Base2, base3: Base3, base4: Base4) {
        self.base1 = base1
        self.base2 = base2
        self.base3 = base3
        self.base4 = base4
    }
    
    public func fetch(_ db: Database) throws -> Fetched {
        return try (
            base1.fetch(db),
            base2.fetch(db),
            base3.fetch(db),
            base4.fetch(db))
    }
    
    mutating public func value(_ fetched: Fetched) -> Value? {
        let v1 = base1.value(fetched.0)
        let v2 = base2.value(fetched.1)
        let v3 = base3.value(fetched.2)
        let v4 = base4.value(fetched.3)
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
}

extension CombinedValueReducer4: ImmediateValueReducer where
    Base1: ImmediateValueReducer,
    Base2: ImmediateValueReducer,
    Base3: ImmediateValueReducer,
    Base4: ImmediateValueReducer
{ }

extension ValueObservation where Reducer == Void {
    public static func combine<R1: ValueReducer, R2: ValueReducer, R3: ValueReducer, R4: ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>)
        -> ValueObservation<CombinedValueReducer4<R1, R2, R3, R4>>
    {
        return ValueObservation<CombinedValueReducer4<R1, R2, R3, R4>>(
            tracking: { try DatabaseRegion.union(
                o1.observedRegion($0),
                o2.observedRegion($0),
                o3.observedRegion($0),
                o4.observedRegion($0)) },
            reducer: { try CombinedValueReducer4(
                base1: o1.makeReducer($0),
                base2: o2.makeReducer($0),
                base3: o3.makeReducer($0),
                base4: o4.makeReducer($0)) })
    }
}

// MARK: - Combine 5 Reducers

public struct CombinedValueReducer5<
    Base1: ValueReducer,
    Base2: ValueReducer,
    Base3: ValueReducer,
    Base4: ValueReducer,
    Base5: ValueReducer>: ValueReducer
{
    public typealias Fetched = (Base1.Fetched, Base2.Fetched, Base3.Fetched, Base4.Fetched, Base5.Fetched)
    public typealias Value = (Base1.Value, Base2.Value, Base3.Value, Base4.Value, Base5.Value)
    var base1: Base1
    var base2: Base2
    var base3: Base3
    var base4: Base4
    var base5: Base5
    private var prev1: Base1.Value? = nil
    private var prev2: Base2.Value? = nil
    private var prev3: Base3.Value? = nil
    private var prev4: Base4.Value? = nil
    private var prev5: Base5.Value? = nil

    init(base1: Base1, base2: Base2, base3: Base3, base4: Base4, base5: Base5) {
        self.base1 = base1
        self.base2 = base2
        self.base3 = base3
        self.base4 = base4
        self.base5 = base5
    }
    
    public func fetch(_ db: Database) throws -> Fetched {
        return try (
            base1.fetch(db),
            base2.fetch(db),
            base3.fetch(db),
            base4.fetch(db),
            base5.fetch(db))
    }
    
    mutating public func value(_ fetched: Fetched) -> Value? {
        let v1 = base1.value(fetched.0)
        let v2 = base2.value(fetched.1)
        let v3 = base3.value(fetched.2)
        let v4 = base4.value(fetched.3)
        let v5 = base5.value(fetched.4)
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
}

extension CombinedValueReducer5: ImmediateValueReducer where
    Base1: ImmediateValueReducer,
    Base2: ImmediateValueReducer,
    Base3: ImmediateValueReducer,
    Base4: ImmediateValueReducer,
    Base5: ImmediateValueReducer
{ }

extension ValueObservation where Reducer == Void {
    public static func combine<R1: ValueReducer, R2: ValueReducer, R3: ValueReducer, R4: ValueReducer, R5: ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>)
        -> ValueObservation<CombinedValueReducer5<R1, R2, R3, R4, R5>>
    {
        return ValueObservation<CombinedValueReducer5<R1, R2, R3, R4, R5>>(
            tracking: { try DatabaseRegion.union(
                o1.observedRegion($0),
                o2.observedRegion($0),
                o3.observedRegion($0),
                o4.observedRegion($0),
                o5.observedRegion($0)) },
            reducer: { try CombinedValueReducer5(
                base1: o1.makeReducer($0),
                base2: o2.makeReducer($0),
                base3: o3.makeReducer($0),
                base4: o4.makeReducer($0),
                base5: o5.makeReducer($0)) })
    }
}
