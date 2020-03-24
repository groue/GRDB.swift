// MARK: - Combine 2 Reducers

extension ValueReducers {
    public struct Combine2<
        R1: _ValueReducer,
        R2: _ValueReducer>: _ValueReducer
    {
        public typealias Fetched = (R1.Fetched, R2.Fetched)
        public typealias Value = (R1.Value, R2.Value)
        var r1: R1
        var r2: R2
        private var p1: R1.Value?
        private var p2: R2.Value?
        
        public var isObservedRegionDeterministic: Bool {
            r1.isObservedRegionDeterministic
                && r2.isObservedRegionDeterministic
        }
        
        init(_ r1: R1, _ r2: R2) {
            self.r1 = r1
            self.r2 = r2
        }
        
        public func fetch(_ db: Database) throws -> Fetched {
            try (
                r1.fetch(db),
                r2.fetch(db))
        }
        
        public mutating func value(_ fetched: Fetched) -> Value? {
            let v1 = r1.value(fetched.0)
            let v2 = r2.value(fetched.1)
            defer {
                if let v1 = v1 { p1 = v1 }
                if let v2 = v2 { p2 = v2 }
            }
            if  v1 != nil || v2 != nil,
                let c1 = v1 ?? p1,
                let c2 = v2 ?? p2
            {
                return (c1, c2)
            } else {
                return nil
            }
        }
    }
}

extension ValueObservation where Reducer == Never {
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>)
        -> ValueObservation<ValueReducers.Combine2<R1, R2>>
    {
        return ValueObservation<ValueReducers.Combine2>(
            makeReducer: { ValueReducers.Combine2(
                o1.makeReducer(),
                o2.makeReducer()) },
            requiresWriteAccess: o1.requiresWriteAccess
                || o2.requiresWriteAccess)
    }
}

extension ValueObservation where Reducer: _ValueReducer {
    public func combine<
        R1: _ValueReducer,
        Combined>(
        _ other: ValueObservation<R1>,
        _ transform: @escaping (Reducer.Value, R1.Value) -> Combined)
        -> ValueObservation<ValueReducers.Map<ValueReducers.Combine2<Reducer, R1>, Combined>>
    {
        return ValueObservation<Never>.combine(self, other).map(transform)
    }
}

// MARK: - Combine 3 Reducers

extension ValueReducers {
    public struct Combine3<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer>: _ValueReducer
    {
        public typealias Fetched = (R1.Fetched, R2.Fetched, R3.Fetched)
        public typealias Value = (R1.Value, R2.Value, R3.Value)
        var r1: R1
        var r2: R2
        var r3: R3
        private var p1: R1.Value?
        private var p2: R2.Value?
        private var p3: R3.Value?
        
        public var isObservedRegionDeterministic: Bool {
            r1.isObservedRegionDeterministic
                && r2.isObservedRegionDeterministic
                && r3.isObservedRegionDeterministic
        }
        
        init(_ r1: R1, _ r2: R2, _ r3: R3) {
            self.r1 = r1
            self.r2 = r2
            self.r3 = r3
        }
        
        public func fetch(_ db: Database) throws -> Fetched {
            try (
                r1.fetch(db),
                r2.fetch(db),
                r3.fetch(db))
        }
        
        public mutating func value(_ fetched: Fetched) -> Value? {
            let v1 = r1.value(fetched.0)
            let v2 = r2.value(fetched.1)
            let v3 = r3.value(fetched.2)
            defer {
                if let v1 = v1 { p1 = v1 }
                if let v2 = v2 { p2 = v2 }
                if let v3 = v3 { p3 = v3 }
            }
            if  v1 != nil || v2 != nil || v3 != nil,
                let c1 = v1 ?? p1,
                let c2 = v2 ?? p2,
                let c3 = v3 ?? p3
            {
                return (c1, c2, c3)
            } else {
                return nil
            }
        }
    }
}

extension ValueObservation where Reducer == Never {
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>)
        -> ValueObservation<ValueReducers.Combine3<R1, R2, R3>>
    {
        return ValueObservation<ValueReducers.Combine3>(
            makeReducer: { ValueReducers.Combine3(
                o1.makeReducer(),
                o2.makeReducer(),
                o3.makeReducer()) },
            requiresWriteAccess: o1.requiresWriteAccess
                || o2.requiresWriteAccess
                || o3.requiresWriteAccess)
    }
}

extension ValueObservation where Reducer: _ValueReducer {
    public func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        Combined>(
        _ observation1: ValueObservation<R1>,
        _ observation2: ValueObservation<R2>,
        _ transform: @escaping (Reducer.Value, R1.Value, R2.Value) -> Combined)
        -> ValueObservation<ValueReducers.Map<ValueReducers.Combine3<Reducer, R1, R2>, Combined>>
    {
        return ValueObservation<Never>
            .combine(
                self,
                observation1,
                observation2)
            .map(transform)
    }
}

// MARK: - Combine 4 Reducers

extension ValueReducers {
    public struct Combine4<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer>: _ValueReducer
    {
        public typealias Fetched = (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched)
        public typealias Value = (R1.Value, R2.Value, R3.Value, R4.Value)
        var r1: R1
        var r2: R2
        var r3: R3
        var r4: R4
        private var p1: R1.Value?
        private var p2: R2.Value?
        private var p3: R3.Value?
        private var p4: R4.Value?
        
        public var isObservedRegionDeterministic: Bool {
            r1.isObservedRegionDeterministic
                && r2.isObservedRegionDeterministic
                && r3.isObservedRegionDeterministic
                && r4.isObservedRegionDeterministic
        }
        
        init(_ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4) {
            self.r1 = r1
            self.r2 = r2
            self.r3 = r3
            self.r4 = r4
        }
        
        public func fetch(_ db: Database) throws -> Fetched {
            try (
                r1.fetch(db),
                r2.fetch(db),
                r3.fetch(db),
                r4.fetch(db))
        }
        
        public mutating func value(_ fetched: Fetched) -> Value? {
            let v1 = r1.value(fetched.0)
            let v2 = r2.value(fetched.1)
            let v3 = r3.value(fetched.2)
            let v4 = r4.value(fetched.3)
            defer {
                if let v1 = v1 { p1 = v1 }
                if let v2 = v2 { p2 = v2 }
                if let v3 = v3 { p3 = v3 }
                if let v4 = v4 { p4 = v4 }
            }
            if  v1 != nil || v2 != nil || v3 != nil || v4 != nil,
                let c1 = v1 ?? p1,
                let c2 = v2 ?? p2,
                let c3 = v3 ?? p3,
                let c4 = v4 ?? p4
            {
                return (c1, c2, c3, c4)
            } else {
                return nil
            }
        }
    }
}

extension ValueObservation where Reducer == Never {
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>)
        -> ValueObservation<ValueReducers.Combine4<R1, R2, R3, R4>>
    {
        return ValueObservation<ValueReducers.Combine4>(
            makeReducer: { ValueReducers.Combine4(
                o1.makeReducer(),
                o2.makeReducer(),
                o3.makeReducer(),
                o4.makeReducer()) },
            requiresWriteAccess: o1.requiresWriteAccess
                || o2.requiresWriteAccess
                || o3.requiresWriteAccess
                || o4.requiresWriteAccess)
    }
}

extension ValueObservation where Reducer: _ValueReducer {
    public func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        Combined>(
        _ observation1: ValueObservation<R1>,
        _ observation2: ValueObservation<R2>,
        _ observation3: ValueObservation<R3>,
        _ transform: @escaping (Reducer.Value, R1.Value, R2.Value, R3.Value) -> Combined)
        -> ValueObservation<ValueReducers.Map<ValueReducers.Combine4<Reducer, R1, R2, R3>, Combined>>
    {
        return ValueObservation<Never>
            .combine(
                self,
                observation1,
                observation2,
                observation3)
            .map(transform)
    }
}

// MARK: - Combine 5 Reducers

extension ValueReducers {
    public struct Combine5<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer>: _ValueReducer
    {
        public typealias Fetched = (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched, R5.Fetched)
        public typealias Value = (R1.Value, R2.Value, R3.Value, R4.Value, R5.Value)
        var r1: R1
        var r2: R2
        var r3: R3
        var r4: R4
        var r5: R5
        private var p1: R1.Value?
        private var p2: R2.Value?
        private var p3: R3.Value?
        private var p4: R4.Value?
        private var p5: R5.Value?
        
        public var isObservedRegionDeterministic: Bool {
            r1.isObservedRegionDeterministic
                && r2.isObservedRegionDeterministic
                && r3.isObservedRegionDeterministic
                && r4.isObservedRegionDeterministic
                && r5.isObservedRegionDeterministic
        }
        
        init(_ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5) {
            self.r1 = r1
            self.r2 = r2
            self.r3 = r3
            self.r4 = r4
            self.r5 = r5
        }
        
        public func fetch(_ db: Database) throws -> Fetched {
            try (
                r1.fetch(db),
                r2.fetch(db),
                r3.fetch(db),
                r4.fetch(db),
                r5.fetch(db))
        }
        
        public mutating func value(_ fetched: Fetched) -> Value? {
            let v1 = r1.value(fetched.0)
            let v2 = r2.value(fetched.1)
            let v3 = r3.value(fetched.2)
            let v4 = r4.value(fetched.3)
            let v5 = r5.value(fetched.4)
            defer {
                if let v1 = v1 { p1 = v1 }
                if let v2 = v2 { p2 = v2 }
                if let v3 = v3 { p3 = v3 }
                if let v4 = v4 { p4 = v4 }
                if let v5 = v5 { p5 = v5 }
            }
            if  v1 != nil || v2 != nil || v3 != nil || v4 != nil || v5 != nil,
                let c1 = v1 ?? p1,
                let c2 = v2 ?? p2,
                let c3 = v3 ?? p3,
                let c4 = v4 ?? p4,
                let c5 = v5 ?? p5
            {
                return (c1, c2, c3, c4, c5)
            } else {
                return nil
            }
        }
    }
}

extension ValueObservation where Reducer == Never {
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>)
        -> ValueObservation<ValueReducers.Combine5<R1, R2, R3, R4, R5>>
    {
        return ValueObservation<ValueReducers.Combine5>(
            makeReducer: { ValueReducers.Combine5(
                o1.makeReducer(),
                o2.makeReducer(),
                o3.makeReducer(),
                o4.makeReducer(),
                o5.makeReducer()) },
            requiresWriteAccess: o1.requiresWriteAccess
                || o2.requiresWriteAccess
                || o3.requiresWriteAccess
                || o4.requiresWriteAccess
                || o5.requiresWriteAccess)
    }
}

extension ValueObservation where Reducer: _ValueReducer {
    public func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        Combined>(
        _ observation1: ValueObservation<R1>,
        _ observation2: ValueObservation<R2>,
        _ observation3: ValueObservation<R3>,
        _ observation4: ValueObservation<R4>,
        _ transform: @escaping (Reducer.Value, R1.Value, R2.Value, R3.Value, R4.Value) -> Combined)
        -> ValueObservation<ValueReducers.Map<ValueReducers.Combine5<Reducer, R1, R2, R3, R4>, Combined>>
    {
        return ValueObservation<Never>
            .combine(
                self,
                observation1,
                observation2,
                observation3,
                observation4)
            .map(transform)
    }
}

// MARK: - Combine 6 Reducers

extension ValueReducers {
    public struct Combine6<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer,
        R6: _ValueReducer>: _ValueReducer
    {
        public typealias Fetched = (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched, R5.Fetched, R6.Fetched)
        public typealias Value = (R1.Value, R2.Value, R3.Value, R4.Value, R5.Value, R6.Value)
        var r1: R1
        var r2: R2
        var r3: R3
        var r4: R4
        var r5: R5
        var r6: R6
        private var p1: R1.Value?
        private var p2: R2.Value?
        private var p3: R3.Value?
        private var p4: R4.Value?
        private var p5: R5.Value?
        private var p6: R6.Value?
        
        public var isObservedRegionDeterministic: Bool {
            r1.isObservedRegionDeterministic
                && r2.isObservedRegionDeterministic
                && r3.isObservedRegionDeterministic
                && r4.isObservedRegionDeterministic
                && r5.isObservedRegionDeterministic
                && r6.isObservedRegionDeterministic
        }
        
        init(_ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6) {
            self.r1 = r1
            self.r2 = r2
            self.r3 = r3
            self.r4 = r4
            self.r5 = r5
            self.r6 = r6
        }
        
        public func fetch(_ db: Database) throws -> Fetched {
            try (
                r1.fetch(db),
                r2.fetch(db),
                r3.fetch(db),
                r4.fetch(db),
                r5.fetch(db),
                r6.fetch(db))
        }
        
        public mutating func value(_ fetched: Fetched) -> Value? {
            let v1 = r1.value(fetched.0)
            let v2 = r2.value(fetched.1)
            let v3 = r3.value(fetched.2)
            let v4 = r4.value(fetched.3)
            let v5 = r5.value(fetched.4)
            let v6 = r6.value(fetched.5)
            defer {
                if let v1 = v1 { p1 = v1 }
                if let v2 = v2 { p2 = v2 }
                if let v3 = v3 { p3 = v3 }
                if let v4 = v4 { p4 = v4 }
                if let v5 = v5 { p5 = v5 }
                if let v6 = v6 { p6 = v6 }
            }
            if  v1 != nil || v2 != nil || v3 != nil || v4 != nil || v5 != nil || v6 != nil,
                let c1 = v1 ?? p1,
                let c2 = v2 ?? p2,
                let c3 = v3 ?? p3,
                let c4 = v4 ?? p4,
                let c5 = v5 ?? p5,
                let c6 = v6 ?? p6
            {
                return (c1, c2, c3, c4, c5, c6)
            } else {
                return nil
            }
        }
    }
}

extension ValueObservation where Reducer == Never {
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer,
        R6: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>,
        _ o6: ValueObservation<R6>)
        -> ValueObservation<ValueReducers.Combine6<R1, R2, R3, R4, R5, R6>>
    {
        return ValueObservation<ValueReducers.Combine6>(
            makeReducer: { ValueReducers.Combine6(
                o1.makeReducer(),
                o2.makeReducer(),
                o3.makeReducer(),
                o4.makeReducer(),
                o5.makeReducer(),
                o6.makeReducer()) },
            requiresWriteAccess: o1.requiresWriteAccess
                || o2.requiresWriteAccess
                || o3.requiresWriteAccess
                || o4.requiresWriteAccess
                || o5.requiresWriteAccess
                || o6.requiresWriteAccess)
    }
}

// MARK: - Combine 7 Reducers

extension ValueReducers {
    public struct Combine7<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer,
        R6: _ValueReducer,
        R7: _ValueReducer>: _ValueReducer
    {
        public typealias Fetched = (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched, R5.Fetched, R6.Fetched, R7.Fetched)
        public typealias Value = (R1.Value, R2.Value, R3.Value, R4.Value, R5.Value, R6.Value, R7.Value)
        var r1: R1
        var r2: R2
        var r3: R3
        var r4: R4
        var r5: R5
        var r6: R6
        var r7: R7
        private var p1: R1.Value?
        private var p2: R2.Value?
        private var p3: R3.Value?
        private var p4: R4.Value?
        private var p5: R5.Value?
        private var p6: R6.Value?
        private var p7: R7.Value?
        
        public var isObservedRegionDeterministic: Bool {
            r1.isObservedRegionDeterministic
                && r2.isObservedRegionDeterministic
                && r3.isObservedRegionDeterministic
                && r4.isObservedRegionDeterministic
                && r5.isObservedRegionDeterministic
                && r6.isObservedRegionDeterministic
                && r7.isObservedRegionDeterministic
        }
        
        init(_ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7) {
            self.r1 = r1
            self.r2 = r2
            self.r3 = r3
            self.r4 = r4
            self.r5 = r5
            self.r6 = r6
            self.r7 = r7
        }
        
        public func fetch(_ db: Database) throws -> Fetched {
            try (
                r1.fetch(db),
                r2.fetch(db),
                r3.fetch(db),
                r4.fetch(db),
                r5.fetch(db),
                r6.fetch(db),
                r7.fetch(db))
        }
        
        public mutating func value(_ fetched: Fetched) -> Value? {
            let v1 = r1.value(fetched.0)
            let v2 = r2.value(fetched.1)
            let v3 = r3.value(fetched.2)
            let v4 = r4.value(fetched.3)
            let v5 = r5.value(fetched.4)
            let v6 = r6.value(fetched.5)
            let v7 = r7.value(fetched.6)
            defer {
                if let v1 = v1 { p1 = v1 }
                if let v2 = v2 { p2 = v2 }
                if let v3 = v3 { p3 = v3 }
                if let v4 = v4 { p4 = v4 }
                if let v5 = v5 { p5 = v5 }
                if let v6 = v6 { p6 = v6 }
                if let v7 = v7 { p7 = v7 }
            }
            if  v1 != nil || v2 != nil || v3 != nil || v4 != nil || v5 != nil || v6 != nil || v7 != nil,
                let c1 = v1 ?? p1,
                let c2 = v2 ?? p2,
                let c3 = v3 ?? p3,
                let c4 = v4 ?? p4,
                let c5 = v5 ?? p5,
                let c6 = v6 ?? p6,
                let c7 = v7 ?? p7
            {
                return (c1, c2, c3, c4, c5, c6, c7)
            } else {
                return nil
            }
        }
    }
}

extension ValueObservation where Reducer == Never {
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer,
        R6: _ValueReducer,
        R7: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>,
        _ o6: ValueObservation<R6>,
        _ o7: ValueObservation<R7>)
        -> ValueObservation<ValueReducers.Combine7<R1, R2, R3, R4, R5, R6, R7>>
    {
        return ValueObservation<ValueReducers.Combine7>(
            makeReducer: { ValueReducers.Combine7(
                o1.makeReducer(),
                o2.makeReducer(),
                o3.makeReducer(),
                o4.makeReducer(),
                o5.makeReducer(),
                o6.makeReducer(),
                o7.makeReducer()) },
            requiresWriteAccess: o1.requiresWriteAccess
                || o2.requiresWriteAccess
                || o3.requiresWriteAccess
                || o4.requiresWriteAccess
                || o5.requiresWriteAccess
                || o6.requiresWriteAccess
                || o7.requiresWriteAccess)
    }
}

// MARK: - Combine 8 Reducers

extension ValueReducers {
    public struct Combine8<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer,
        R6: _ValueReducer,
        R7: _ValueReducer,
        R8: _ValueReducer>: _ValueReducer
    {
        // swiftlint:disable:next line_length
        public typealias Fetched = (R1.Fetched, R2.Fetched, R3.Fetched, R4.Fetched, R5.Fetched, R6.Fetched, R7.Fetched, R8.Fetched)
        public typealias Value = (R1.Value, R2.Value, R3.Value, R4.Value, R5.Value, R6.Value, R7.Value, R8.Value)
        var r1: R1
        var r2: R2
        var r3: R3
        var r4: R4
        var r5: R5
        var r6: R6
        var r7: R7
        var r8: R8
        private var p1: R1.Value?
        private var p2: R2.Value?
        private var p3: R3.Value?
        private var p4: R4.Value?
        private var p5: R5.Value?
        private var p6: R6.Value?
        private var p7: R7.Value?
        private var p8: R8.Value?
        
        public var isObservedRegionDeterministic: Bool {
            r1.isObservedRegionDeterministic
                && r2.isObservedRegionDeterministic
                && r3.isObservedRegionDeterministic
                && r4.isObservedRegionDeterministic
                && r5.isObservedRegionDeterministic
                && r6.isObservedRegionDeterministic
                && r7.isObservedRegionDeterministic
                && r8.isObservedRegionDeterministic
        }
        
        init(_ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7, _ r8: R8) {
            self.r1 = r1
            self.r2 = r2
            self.r3 = r3
            self.r4 = r4
            self.r5 = r5
            self.r6 = r6
            self.r7 = r7
            self.r8 = r8
        }
        
        public func fetch(_ db: Database) throws -> Fetched {
            try (
                r1.fetch(db),
                r2.fetch(db),
                r3.fetch(db),
                r4.fetch(db),
                r5.fetch(db),
                r6.fetch(db),
                r7.fetch(db),
                r8.fetch(db))
        }
        
        public mutating func value(_ fetched: Fetched) -> Value? {
            let v1 = r1.value(fetched.0)
            let v2 = r2.value(fetched.1)
            let v3 = r3.value(fetched.2)
            let v4 = r4.value(fetched.3)
            let v5 = r5.value(fetched.4)
            let v6 = r6.value(fetched.5)
            let v7 = r7.value(fetched.6)
            let v8 = r8.value(fetched.7)
            defer {
                if let v1 = v1 { p1 = v1 }
                if let v2 = v2 { p2 = v2 }
                if let v3 = v3 { p3 = v3 }
                if let v4 = v4 { p4 = v4 }
                if let v5 = v5 { p5 = v5 }
                if let v6 = v6 { p6 = v6 }
                if let v7 = v7 { p7 = v7 }
                if let v8 = v8 { p8 = v8 }
            }
            if  v1 != nil || v2 != nil || v3 != nil || v4 != nil || v5 != nil || v6 != nil || v7 != nil || v8 != nil,
                let c1 = v1 ?? p1,
                let c2 = v2 ?? p2,
                let c3 = v3 ?? p3,
                let c4 = v4 ?? p4,
                let c5 = v5 ?? p5,
                let c6 = v6 ?? p6,
                let c7 = v7 ?? p7,
                let c8 = v8 ?? p8
            {
                return (c1, c2, c3, c4, c5, c6, c7, c8)
            } else {
                return nil
            }
        }
    }
}

extension ValueObservation where Reducer == Never {
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer,
        R6: _ValueReducer,
        R7: _ValueReducer,
        R8: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>,
        _ o6: ValueObservation<R6>,
        _ o7: ValueObservation<R7>,
        _ o8: ValueObservation<R8>)
        -> ValueObservation<ValueReducers.Combine8<R1, R2, R3, R4, R5, R6, R7, R8>>
    {
        return ValueObservation<ValueReducers.Combine8>(
            makeReducer: { ValueReducers.Combine8(
                o1.makeReducer(),
                o2.makeReducer(),
                o3.makeReducer(),
                o4.makeReducer(),
                o5.makeReducer(),
                o6.makeReducer(),
                o7.makeReducer(),
                o8.makeReducer()) },
            requiresWriteAccess: o1.requiresWriteAccess
                || o2.requiresWriteAccess
                || o3.requiresWriteAccess
                || o4.requiresWriteAccess
                || o5.requiresWriteAccess
                || o6.requiresWriteAccess
                || o7.requiresWriteAccess
                || o8.requiresWriteAccess)
    }
}
