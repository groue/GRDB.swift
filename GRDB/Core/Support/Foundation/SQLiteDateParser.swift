import Foundation

// inspired by: http://jordansmith.io/performant-date-parsing/

@usableFromInline
struct SQLiteDateParser {
    @usableFromInline
    init() { }
    
    func components(from dateString: String) -> DatabaseDateComponents? {
        dateString.withCString { cString in
            components(cString: cString, length: strlen(cString))
        }
    }
    
    @usableFromInline
    func components(cString: UnsafePointer<CChar>, length: Int) -> DatabaseDateComponents? {
        assert(strlen(cString) == length)
        
        // "HH:MM" is the shortest valid string
        guard length >= 5 else { return nil }
        
        // "YYYY-..." -> datetime
        if cString[4] == UInt8(ascii: "-") {
            var components = DateComponents()
            var parser = Parser(cString: cString, length: length)
            guard let format = parseDatetimeFormat(parser: &parser, into: &components),
                  parser.length == 0
            else {
                return nil
            }
            return DatabaseDateComponents(components, format: format)
        }
        
        // "HH-:..." -> time
        if cString[2] == UInt8(ascii: ":") {
            var components = DateComponents()
            var parser = Parser(cString: cString, length: length)
            guard let format = parseTimeFormat(parser: &parser, into: &components),
                  parser.length == 0
            else {
                return nil
            }
            return DatabaseDateComponents(components, format: format)
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
        parser: inout Parser,
        into components: inout DateComponents)
    -> DatabaseDateComponents.Format?
    {
        guard let year = parser.parseNNNN(),
              parser.parse("-"),
              let month = parser.parseNN(),
              parser.parse("-"),
              let day = parser.parseNN()
        else { return nil }
        
        components.year = year
        components.month = month
        components.day = day
        if parser.length == 0 { return .YMD }
        
        guard parser.parse(" ") || parser.parse("T")
        else {
            return nil
        }
        
        switch parseTimeFormat(parser: &parser, into: &components) {
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
        parser: inout Parser,
        into components: inout DateComponents)
    -> DatabaseDateComponents.Format?
    {
        guard let hour = parser.parseNN(),
              parser.parse(":"),
              let minute = parser.parseNN()
        else { return nil }
        
        components.hour = hour
        components.minute = minute
        if parser.length == 0 || parseTimeZone(parser: &parser, into: &components) { return .HM }
        
        guard parser.parse(":"),
              let second = parser.parseNN()
        else { return nil }
        
        components.second = second
        if parser.length == 0 || parseTimeZone(parser: &parser, into: &components) { return .HMS }
        
        guard parser.parse(".") else { return nil }
        
        // Parse one to three digits
        // Rationale: https://github.com/groue/GRDB.swift/pull/362
        var nanosecond = 0
        guard parser.parseDigit(into: &nanosecond) else { return nil }
        if parser.length == 0 || parseTimeZone(parser: &parser, into: &components) {
            components.nanosecond = nanosecond * 100_000_000
            return .HMSS
        }
        guard parser.parseDigit(into: &nanosecond) else { return nil }
        if parser.length == 0 || parseTimeZone(parser: &parser, into: &components) {
            components.nanosecond = nanosecond * 10_000_000
            return .HMSS
        }
        guard parser.parseDigit(into: &nanosecond) else { return nil }
        components.nanosecond = nanosecond * 1_000_000
        while parser.parseDigit() != nil { }
        _ = parseTimeZone(parser: &parser, into: &components)
        return .HMSS
    }
    
    private func parseTimeZone(
        parser: inout Parser,
        into components: inout DateComponents)
    -> Bool
    {
        if parser.parse("Z") {
            components.timeZone = TimeZone(secondsFromGMT: 0)
            return true
        }
        
        if parser.parse("+"),
           let hour = parser.parseNN(),
           parser.parse(":"),
           let minute = parser.parseNN()
        {
            components.timeZone = TimeZone(secondsFromGMT: hour * 3600 + minute * 60)
            return true
        }
        
        if parser.parse("-"),
           let hour = parser.parseNN(),
           parser.parse(":"),
           let minute = parser.parseNN()
        {
            components.timeZone = TimeZone(secondsFromGMT: -(hour * 3600 + minute * 60))
            return true
        }
        
        return false
    }
    
    private struct Parser {
        var cString: UnsafePointer<CChar>
        var length: Int
        
        private mutating func shift() {
            cString += 1
            length -= 1
        }
        
        mutating func parse(_ scalar: Unicode.Scalar) -> Bool {
            guard length > 0, cString[0] == UInt8(ascii: scalar) else {
                return false
            }
            shift()
            return true
        }
        
        mutating func parseDigit() -> Int? {
            guard length > 0 else {
                return nil
            }
            let char = cString[0]
            let digit = char - CChar(bitPattern: UInt8(ascii: "0"))
            guard digit >= 0 && digit <= 9 else {
                return nil
            }
            shift()
            return Int(digit)
        }
        
        mutating func parseDigit(into number: inout Int) -> Bool {
            guard let digit = parseDigit() else {
                return false
            }
            number = number * 10 + digit
            return true
        }
        
        mutating func parseNNNN() -> Int? {
            var number = 0
            guard parseDigit(into: &number)
                    && parseDigit(into: &number)
                    && parseDigit(into: &number)
                    && parseDigit(into: &number)
            else {
                // Don't restore self to initial state because we don't need it
                return nil
            }
            return number
        }
        
        mutating func parseNN() -> Int? {
            var number = 0
            guard parseDigit(into: &number)
                    && parseDigit(into: &number)
            else {
                // Don't restore self to initial state because we don't need it
                return nil
            }
            return number
        }
    }
}
