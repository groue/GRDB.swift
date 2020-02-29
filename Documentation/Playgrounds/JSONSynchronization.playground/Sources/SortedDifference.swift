// Copyright (C) 2019 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

/// Given two sequences (left and right), this sequence tells whether elements
/// are only found on the left, on the right, or on both sides.
public struct SortedDifference<LeftSequence, RightSequence, ID>: Sequence where
    LeftSequence: Sequence,
    RightSequence: Sequence,
    ID: Comparable
{
    private let left: LeftSequence
    private let right: RightSequence
    private let lID: (LeftSequence.Element) -> ID
    private let rID: (RightSequence.Element) -> ID
    
    /// Given two sequences (left and right), returns a sequence which tells
    /// whether elements are only found on the left, on the right, or on
    /// both sides.
    ///
    /// Both input sequences do not have to share the same element type, but
    /// their elements must share a common comparable id.
    ///
    /// For example:
    ///
    ///     // Prints:
    ///     // - common(Left(id: 1), Right(id: 1))
    ///     // - left(Left(id: 2))
    ///     struct Left { var id: Int }
    ///     struct Right { var id: Int }
    ///     for change in SortedDifference(
    ///         left: [Left(id: 1), Left(id: 2)],
    ///         identifiedBy: { $0.id },
    ///         right: [Right(id: 1)],
    ///         identifiedBy: { $0.id })
    ///     {
    ///         print(change)
    ///     }
    ///
    /// - precondition: Both input sequences must be sorted by id.
    /// - precondition: Ids must be unique in each sequences.
    /// - parameters:
    ///     - left: The left sequence.
    ///     - right: The right sequence.
    ///     - leftID: A function that returns the id of a left element.
    ///     - rightID: A function that returns the id of a right element.
    public init(
        left: LeftSequence,
        identifiedBy leftID: @escaping (LeftSequence.Element) -> ID,
        right: RightSequence,
        identifiedBy rightID: @escaping (RightSequence.Element) -> ID)
    {
        self.left = left
        self.right = right
        self.lID = leftID
        self.rID = rightID
    }
    
    public func makeIterator() -> Iterator {
        Iterator(
            lIterator: left.makeIterator(),
            rIterator: right.makeIterator(),
            lID: lID,
            rID: rID)
    }
    
    public struct Iterator: IteratorProtocol {
        private var lIterator: LeftSequence.Iterator
        private var rIterator: RightSequence.Iterator
        private var lOpt: LeftSequence.Element?
        private var rOpt: RightSequence.Element?
        private let lID: (LeftSequence.Element) -> ID
        private let rID: (RightSequence.Element) -> ID
        
        init(
            lIterator: LeftSequence.Iterator,
            rIterator: RightSequence.Iterator,
            lID: @escaping (LeftSequence.Element) -> ID,
            rID: @escaping (RightSequence.Element) -> ID)
        {
            self.lIterator = lIterator
            self.rIterator = rIterator
            self.lID = lID
            self.rID = rID
            self.lOpt = self.lIterator.next()
            self.rOpt = self.rIterator.next()
        }
        
        public mutating func next() -> SortedDifferenceChange<LeftSequence.Element, RightSequence.Element>? {
            switch (lOpt, rOpt) {
            case let (lElem?, rElem?):
                let (lID, rID) = (self.lID(lElem), self.rID(rElem))
                if lID > rID {
                    rOpt = rIterator.next()
                    return .right(rElem)
                } else if lID == rID {
                    (lOpt, rOpt) = (lIterator.next(), rIterator.next())
                    return .common(lElem, rElem)
                } else {
                    lOpt = lIterator.next()
                    return .left(lElem)
                }
            case let (nil, rElem?):
                rOpt = rIterator.next()
                return .right(rElem)
            case let (lElem?, nil):
                lOpt = lIterator.next()
                return .left(lElem)
            case (nil, nil):
                return nil
            }
        }
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension SortedDifference where
    LeftSequence.Element: Identifiable,
    RightSequence.Element: Identifiable,
    LeftSequence.Element.ID == ID,
    RightSequence.Element.ID == ID
{
    /// Given two sequences (left and right), returns a sequence which tells
    /// whether elements are only found on the left, on the right, or on
    /// both sides.
    ///
    /// Both input sequences do not have to share the same element type, but
    /// their elements must share a common comparable id.
    ///
    /// For example:
    ///
    ///     // Prints:
    ///     // - common(Left(id: 1), Right(id: 1))
    ///     // - left(Left(id: 2))
    ///     struct Left: Identifiable { var id: Int }
    ///     struct Right: Identifiable { var id: Int }
    ///     for change in SortedDifference(
    ///         left: [Left(id: 1), Left(id: 2)],
    ///         right: [Right(id: 1)])
    ///     {
    ///         print(change)
    ///     }
    ///
    /// - precondition: Both input sequences must be sorted by id.
    /// - precondition: Ids must be unique in each sequences.
    /// - parameters:
    ///     - left: The left sequence.
    ///     - right: The right sequence.
    public init(left: LeftSequence, right: RightSequence) {
        self.init(
            left: left,
            identifiedBy: { $0.id },
            right: right,
            identifiedBy: { $0.id })
    }
}

extension SortedDifference where
    LeftSequence.Element: Comparable,
    RightSequence.Element == LeftSequence.Element,
    LeftSequence.Element == ID
{
    /// Given two sequences (left and right), this sequence tells whether
    /// elements are only found on the left, on the right, or on both sides.
    ///
    /// For example:
    ///
    ///     // Prints:
    ///     // - common(1, 1)
    ///     // - left(2)
    ///     for change in SortedDifference(left: [1, 2], right: [1]) {
    ///         print(change)
    ///     }
    ///
    /// - precondition: Both input sequences must be sorted.
    /// - precondition: Both input sequences must contain unique elements.
    /// - parameters:
    ///     - left: The left sequence.
    ///     - right: The right sequence.
    public init(left: LeftSequence, right: RightSequence) {
        self.init(
            left: left,
            identifiedBy: { $0 },
            right: right,
            identifiedBy: { $0 })
    }
}

/// An element of the SortedDifference sequence.
public enum SortedDifferenceChange<Left, Right> {
    /// An element only found in the left sequence
    case left(Left)
    /// An element only found in the right sequence
    case right(Right)
    /// Left and right elements share a common id
    case common(Left, Right)
}

extension SortedDifferenceChange: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .left(lhs):
            return "left(\(String(describing: lhs)))"
        case let .right(rhs):
            return "right(\(String(describing: rhs)))"
        case let .common(lhs, rhs):
            return "common(\(String(describing: lhs)), \(String(describing: rhs)))"
        }
    }
}

extension SortedDifferenceChange: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .left(lhs):
            return "left(\(String(reflecting: lhs)))"
        case let .right(rhs):
            return "right(\(String(reflecting: rhs)))"
        case let .common(lhs, rhs):
            return "common(\(String(reflecting: lhs)), \(String(reflecting: rhs)))"
        }
    }
}

extension SortedDifferenceChange: Equatable where
    Left: Equatable,
    Right: Equatable
{ }
