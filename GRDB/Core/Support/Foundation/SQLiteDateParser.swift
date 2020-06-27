import Foundation

// inspired by: http://jordansmith.io/performant-date-parsing/

class SQLiteDateParser {
    
    private struct ParserComponents {
        var year: Int32 = 0
        var month: Int32 = 0
        var day: Int32 = 0
        var hour: Int32 = 0
        var minute: Int32 = 0
        var second: Int32 = 0
        var nanosecond = ContiguousArray<CChar>(repeating: 0, count: 10) // 9 digits, and trailing \0
    }
    
    func components(from dateString: String) -> DatabaseDateComponents? {
        dateString.withCString { cString in
            components(cString: cString, length: strlen(cString))
        }
    }
    
    func components(cString: UnsafePointer<CChar>, length: Int) -> DatabaseDateComponents? {
        assert(strlen(cString) == length)
        
        // "HH:MM" is the shortest valid string
        guard length >= 5 else { return nil }
        
        // "YYYY-..." -> datetime
        if cString[4] == UInt8(ascii: "-") {
            var components = DateComponents()
            return parseDatetimeFormat(cString: cString, length: length, into: &components)
                .map { DatabaseDateComponents(components, format: $0)
            }
        }
        
        // "HH-:..." -> time
        if cString[2] == UInt8(ascii: ":") {
            var components = DateComponents()
            return parseTimeFormat(cString: cString, length: length, into: &components)
                .map { DatabaseDateComponents(components, format: $0)
            }
        }
        
        // Invalid
        return nil
    }
    
    // - YYYY-MM-DD
    // - YYYY-MM-DD HH:MM
    // - YYYY-MM-DD HH:MM:SS
    // - YYYY-MM-DD HH:MM:SS.SSS
    // - YYYY-MM-DDTHH:MM
    // - YYYY-MM-DDTHH:MM:SS
    // - YYYY-MM-DDTHH:MM:SS.SSS
    private func parseDatetimeFormat(
        cString: UnsafePointer<CChar>,
        length: Int,
        into components: inout DateComponents)
        -> DatabaseDateComponents.Format?
    {
        var cString = cString
        var remainingLength = length
        
        if remainingLength < 10 { return nil }
        remainingLength -= 10
        guard
            let year = parseNNNN(cString: &cString),
            parse("-", cString: &cString),
            let month = parseNN(cString: &cString),
            parse("-", cString: &cString),
            let day = parseNN(cString: &cString)
            else { return nil }
        
        components.year = year
        components.month = month
        components.day = day
        if remainingLength == 0 { return .YMD }
        
        remainingLength -= 1
        guard parse(" ", cString: &cString) || parse("T", cString: &cString) else {
            return nil
        }
        
        switch parseTimeFormat(cString: cString, length: remainingLength, into: &components) {
        case .HM: return .YMD_HM
        case .HMS: return .YMD_HMS
        case .HMSS: return .YMD_HMSS
        default: return nil
        }
    }
    
    // - HH:MM
    // - HH:MM:SS
    // - HH:MM:SS.SSS
    private func parseTimeFormat(
        cString: UnsafePointer<CChar>,
        length: Int,
        into components: inout DateComponents)
        -> DatabaseDateComponents.Format?
    {
        var cString = cString
        var remainingLength = length
        
        if remainingLength < 5 { return nil }
        remainingLength -= 5
        guard
            let hour = parseNN(cString: &cString),
            parse(":", cString: &cString),
            let minute = parseNN(cString: &cString)
            else { return nil }
        
        components.hour = hour
        components.minute = minute
        if remainingLength == 0 { return .HM }
        
        if remainingLength < 3 { return nil }
        remainingLength -= 3
        guard
            parse(":", cString: &cString),
            let second = parseNN(cString: &cString)
            else { return nil }
        
        components.second = second
        if remainingLength == 0 { return .HMS }
        
        if remainingLength < 1 { return nil }
        remainingLength -= 1
        guard parse(".", cString: &cString) else { return nil }
        
        // Parse three digits
        // Rationale: https://github.com/groue/GRDB.swift/pull/362
        remainingLength = min(remainingLength, 3)
        var nanosecond = 0
        for _ in 0..<remainingLength {
            guard parseDigit(cString: &cString, into: &nanosecond) else { return nil }
        }
        nanosecond *= [1_000_000_000, 100_000_000, 10_000_000, 1_000_000][remainingLength]
        components.nanosecond = nanosecond
        return .HMSS
    }
    
    @inline(__always)
    private func parseNNNN(cString: inout UnsafePointer<CChar>) -> Int? {
        var number = 0
        guard parseDigit(cString: &cString, into: &number)
            && parseDigit(cString: &cString, into: &number)
            && parseDigit(cString: &cString, into: &number)
            && parseDigit(cString: &cString, into: &number)
        else {
            return nil
        }
        return number
    }
    
    @inline(__always)
    private func parseNN(cString: inout UnsafePointer<CChar>) -> Int? {
        var number = 0
        guard parseDigit(cString: &cString, into: &number)
            && parseDigit(cString: &cString, into: &number)
        else {
            return nil
        }
        return number
    }
    
    @inline(__always)
    private func parse(_ scalar: Unicode.Scalar, cString: inout UnsafePointer<CChar>) -> Bool {
        guard cString[0] == UInt8(ascii: scalar) else {
            return false
        }
        cString += 1
        return true
    }
    
    @inline(__always)
    private func parseDigit(cString: inout UnsafePointer<CChar>, into number: inout Int) -> Bool {
        let char = cString[0]
        let digit = char - CChar(bitPattern: UInt8(ascii: "0"))
        guard digit >= 0 && digit <= 9 else {
            return false
        }
        cString += 1
        number = number * 10 + Int(digit)
        return true
    }
}
