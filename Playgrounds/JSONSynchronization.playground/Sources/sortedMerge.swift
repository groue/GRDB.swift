/// Given two sorted sequences (left and right), this function emits "merge steps"
/// which tell whether elements are only found on the left, on the right, or on
/// both sides.
///
/// Both sequences do not have to share the same element type. Yet elements must
/// share a common comparable *key*.
///
/// Both sequences must be sorted by this key.
///
/// Keys must be unique in both sequences.
///
/// The example below compare two sequences sorted by integer representation,
/// and prints:
///
/// - Left: 1
/// - Common: 2, 2
/// - Common: 3, 3
/// - Right: 4
///
///     for mergeStep in sortedMerge(
///         left: [1,2,3],
///         right: ["2", "3", "4"],
///         leftKey: { $0 },
///         rightKey: { Int($0)! })
///     {
///         switch mergeStep {
///         case .Left(let left):
///             print("- Left: \(left)")
///         case .Right(let right):
///             print("- Right: \(right)")
///         case .Common(let left, let right):
///             print("- Common: \(left), \(right)")
///         }
///     }
///
/// - parameters:
///     - left: The left sequence.
///     - right: The right sequence.
///     - leftKey: A function that returns the key of a left element.
///     - rightKey: A function that returns the key of a right element.
/// - returns: A sequence of MergeStep
public func sortedMerge<LeftSequence: SequenceType, RightSequence: SequenceType, Key: Comparable>(
    left lSeq: LeftSequence,
    right rSeq: RightSequence,
    leftKey: LeftSequence.Generator.Element -> Key,
    rightKey: RightSequence.Generator.Element -> Key) -> AnySequence<MergeStep<LeftSequence.Generator.Element, RightSequence.Generator.Element>>
{
    return AnySequence { () -> AnyGenerator<MergeStep<LeftSequence.Generator.Element, RightSequence.Generator.Element>> in
        var (lGen, rGen) = (lSeq.generate(), rSeq.generate())
        var (lOpt, rOpt) = (lGen.next(), rGen.next())
        return AnyGenerator {
            switch (lOpt, rOpt) {
            case (let lElem?, let rElem?):
                let (lKey, rKey) = (leftKey(lElem), rightKey(rElem))
                if lKey > rKey {
                    rOpt = rGen.next()
                    return .Right(rElem)
                } else if lKey == rKey {
                    (lOpt, rOpt) = (lGen.next(), rGen.next())
                    return .Common(lElem, rElem)
                } else {
                    lOpt = lGen.next()
                    return .Left(lElem)
                }
            case (nil, let rElem?):
                rOpt = rGen.next()
                return .Right(rElem)
            case (let lElem?, nil):
                lOpt = lGen.next()
                return .Left(lElem)
            case (nil, nil):
                return nil
            }
        }
    }
}

/**
 Support for sortedMerge()
 */
public enum MergeStep<LeftElement, RightElement> {
    /// An element only found in the left sequence:
    case Left(LeftElement)
    /// An element only found in the right sequence:
    case Right(RightElement)
    /// Left and right elements share a common key:
    case Common(LeftElement, RightElement)
}
