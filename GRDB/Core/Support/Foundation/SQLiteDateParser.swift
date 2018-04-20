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
        var nanosecond = ContiguousArray<CChar>.init(repeating: 0, count: 11)
    }

    func components(from dateString: String) -> DatabaseDateComponents? {
        guard dateString.count >= 5 else { return nil }

        if dateString[dateString.index(dateString.startIndex, offsetBy: 4)] == "-" {
            /***
             Note: A date string with full nanosecond precision is 29 chars.
             This call is truncating the nanosecond fraction to a max of 3 sig figs (ie 23 chars).
             */
            return datetimeComponents(from: String(dateString.prefix(23)))
        }

        if dateString[dateString.index(dateString.startIndex, offsetBy: 2)] == ":" {
            /***
             Note: A time string with full nanosecond precision is 18 chars.
             This call is truncating the nanosecond fraction to a max of 3 sig figs (ie 12 chars).
             */
            return timeComponents(from: String(dateString.prefix(12)))
        }

        return nil
    }

    // - YYYY-MM-DD
    // - YYYY-MM-DD HH:MM
    // - YYYY-MM-DD HH:MM:SS
    // - YYYY-MM-DD HH:MM:SS.SSS
    // - YYYY-MM-DDTHH:MM
    // - YYYY-MM-DDTHH:MM:SS
    // - YYYY-MM-DDTHH:MM:SS.SSS
    private func datetimeComponents(from dateString: String) -> DatabaseDateComponents? {
        var parserComponents = ParserComponents()
        
        // TODO: Get rid of this pyramid when SE-0210 has shipped
        let parseCount = withUnsafeMutablePointer(to: &parserComponents.year) { yearP in
            withUnsafeMutablePointer(to: &parserComponents.month) { monthP in
                withUnsafeMutablePointer(to: &parserComponents.day) { dayP in
                    withUnsafeMutablePointer(to: &parserComponents.hour) { hourP in
                        withUnsafeMutablePointer(to: &parserComponents.minute) { minuteP in
                            withUnsafeMutablePointer(to: &parserComponents.second) { secondP in
                                parserComponents.nanosecond.withUnsafeMutableBufferPointer { nanosecondBuffer in
                                    // TODO: what if vsscanf parses a string longer than nanosecond length?
                                    withVaList([yearP, monthP, dayP, hourP, minuteP, secondP, nanosecondBuffer.baseAddress!]) { pointer in
                                        vsscanf(dateString, "%d-%d-%d%*c%d:%d:%d.%s", pointer)
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
    private func timeComponents(from timeString: String) -> DatabaseDateComponents? {
        var parserComponents = ParserComponents()
        // TODO: Get rid of this pyramid when SE-0210 has shipped
        let parseCount = withUnsafeMutablePointer(to: &parserComponents.hour) { hourP in
            withUnsafeMutablePointer(to: &parserComponents.minute) { minuteP in
                withUnsafeMutablePointer(to: &parserComponents.second) { secondP in
                    parserComponents.nanosecond.withUnsafeMutableBufferPointer { nanosecondBuffer in
                        // TODO: what if vsscanf parses a string longer than nanosecond length?
                        withVaList([hourP, minuteP, secondP, nanosecondBuffer.baseAddress!]) { pointer in
                            vsscanf(timeString, "%d:%d:%d.%s", pointer)
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

        components.nanosecond = nanosecondsInt(for: parserComponents.nanosecond)

        return DatabaseDateComponents(components, format: .HMSS)
    }

    private func nanosecondsInt(for nanosecond: ContiguousArray<CChar>) -> Int {
        let nanoString = "0." + nanosecond.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        guard let doubleValue = Double(nanoString) else { return 0 }
        return Int(doubleValue * 1_000_000_000)
    }
}
