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
        return dateString.withCString { cString in
            components(cString: cString, length: strlen(cString))
        }
    }
    
    func components(cString: UnsafePointer<CChar>, length: Int) -> DatabaseDateComponents? {
        assert(strlen(cString) == length)
        
        // "HH:MM" is the shortest valid string
        guard length >= 5 else { return nil }
        
        // "YYYY-..." -> datetime
        if cString[4] == UInt8(ascii: "-") {
            return datetimeComponents(cString: cString, length: length)
        }
        
        // "HH-:..." -> time
        if cString[2] == UInt8(ascii: ":") {
            return timeComponents(cString: cString, length: length)
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
    private func datetimeComponents(cString: UnsafePointer<CChar>, length: Int) -> DatabaseDateComponents? {
        var parserComponents = ParserComponents()
        
        // TODO: Get rid of this pyramid when SE-0210 has shipped
        let parseCount = withUnsafeMutablePointer(to: &parserComponents.year) { yearP in
            withUnsafeMutablePointer(to: &parserComponents.month) { monthP in
                withUnsafeMutablePointer(to: &parserComponents.day) { dayP in
                    withUnsafeMutablePointer(to: &parserComponents.hour) { hourP in
                        withUnsafeMutablePointer(to: &parserComponents.minute) { minuteP in
                            withUnsafeMutablePointer(to: &parserComponents.second) { secondP in
                                parserComponents.nanosecond.withUnsafeMutableBufferPointer { nanosecondBuffer in
                                    // swiftlint:disable:next line_length
                                    withVaList([yearP, monthP, dayP, hourP, minuteP, secondP, nanosecondBuffer.baseAddress!]) { pointer in
                                        vsscanf(cString, "%4d-%2d-%2d%*1[ T]%2d:%2d:%2d.%9s", pointer)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        guard parseCount >= 3 else { return nil }
        
        var components = DateComponents()
        components.year = Int(parserComponents.year)
        components.month = Int(parserComponents.month)
        components.day = Int(parserComponents.day)
        
        guard parseCount >= 5 else { return DatabaseDateComponents(components, format: .YMD) }
        
        components.hour = Int(parserComponents.hour)
        components.minute = Int(parserComponents.minute)
        
        guard parseCount >= 6 else { return DatabaseDateComponents(components, format: .YMD_HM) }
        
        components.second = Int(parserComponents.second)
        
        guard parseCount >= 7 else { return DatabaseDateComponents(components, format: .YMD_HMS) }
        
        components.nanosecond = nanosecondsInt(for: parserComponents.nanosecond)
        
        return DatabaseDateComponents(components, format: .YMD_HMSS)
    }
    
    // - HH:MM
    // - HH:MM:SS
    // - HH:MM:SS.SSS
    private func timeComponents(cString: UnsafePointer<CChar>, length: Int) -> DatabaseDateComponents? {
        var parserComponents = ParserComponents()
        
        // TODO: Get rid of this pyramid when SE-0210 has shipped
        let parseCount = withUnsafeMutablePointer(to: &parserComponents.hour) { hourP in
            withUnsafeMutablePointer(to: &parserComponents.minute) { minuteP in
                withUnsafeMutablePointer(to: &parserComponents.second) { secondP in
                    parserComponents.nanosecond.withUnsafeMutableBufferPointer { nanosecondBuffer in
                        withVaList([hourP, minuteP, secondP, nanosecondBuffer.baseAddress!]) { pointer in
                            vsscanf(cString, "%2d:%2d:%2d.%9s", pointer)
                        }
                    }
                }
            }
        }
        
        guard parseCount >= 2 else { return nil }
        
        var components = DateComponents()
        components.hour = Int(parserComponents.hour)
        components.minute = Int(parserComponents.minute)
        
        guard parseCount >= 3 else { return DatabaseDateComponents(components, format: .HM) }
        
        components.second = Int(parserComponents.second)
        
        guard parseCount >= 4 else { return DatabaseDateComponents(components, format: .HMS) }
        
        guard let nanoseconds = nanosecondsInt(for: parserComponents.nanosecond) else { return nil }
        components.nanosecond = nanoseconds
        
        return DatabaseDateComponents(components, format: .HMSS)
    }
    
    private func nanosecondsInt(for nanosecond: ContiguousArray<CChar>) -> Int? {
        // truncate after the third digit
        var result = 0
        let multipliers = [100_000_000, 10_000_000, 1_000_000, 100_000, 10_000, 1_000, 100, 10, 1]
        for (char, multiplier) in zip(nanosecond.prefix(3), multipliers) {
            if char == 0 { return result }
            let digit = Int(char) - 48 /* '0' */
            guard (0...9).contains(digit) else { return nil }
            result += multiplier * digit
        }
        return result
    }
}
