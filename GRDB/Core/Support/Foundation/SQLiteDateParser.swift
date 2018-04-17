import Foundation

// inspired by: http://jordansmith.io/performant-date-parsing/

class SQLiteDateParser {

    private static var mutex: pthread_mutex_t = {
        var mutex = pthread_mutex_t()
        pthread_mutex_init(&mutex, nil)
        return mutex
    }()

    private static let year = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    private static let month = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    private static let day = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    private static let hour = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    private static let minute = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    private static let second = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    private static let nanosecond = UnsafeMutablePointer<CChar>.allocate(capacity: 11)

    public static func components(from dateString: String) -> DatabaseDateComponents? {
        guard dateString.count >= 5 else { return nil }

        if dateString[dateString.index(dateString.startIndex, offsetBy: 4)] == "-" {
            // a date string with full nanosecond precision is 29 chars
            return datetimeComponents(from: String(dateString.prefix(29)))
        }

        if dateString[dateString.index(dateString.startIndex, offsetBy: 2)] == ":" {
            // a time string with full nanosecond precision is 18 chars
            return timeComponents(from: String(dateString.prefix(18)))
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
    private static func datetimeComponents(from dateString: String) -> DatabaseDateComponents? {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }

        let parseCount = withVaList([year, month, day, hour, minute, second, nanosecond]) { pointer in
            vsscanf(dateString, "%d-%d-%d%*c%d:%d:%d.%s", pointer)
        }

        guard parseCount >= 3 else { return nil }

        var components = DateComponents()
        components.year = Int(year.pointee)
        components.month = Int(month.pointee)
        components.day = Int(day.pointee)

        guard parseCount >= 5 else { return DatabaseDateComponents(components, format: .YMD) }

        components.hour = Int(hour.pointee)
        components.minute = Int(minute.pointee)

        guard parseCount >= 6 else { return DatabaseDateComponents(components, format: .YMD_HM) }

        components.second = Int(second.pointee)

        guard parseCount >= 7 else { return DatabaseDateComponents(components, format: .YMD_HMS) }

        components.nanosecond = nanosecondsInt(for: nanosecond)

        return DatabaseDateComponents(components, format: .YMD_HMSS)
    }

    // - HH:MM
    // - HH:MM:SS
    // - HH:MM:SS.SSS
    private static func timeComponents(from timeString: String) -> DatabaseDateComponents? {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }

        let parseCount = withVaList([hour, minute, second, nanosecond]) { pointer in
            vsscanf(timeString, "%d:%d:%d.%s", pointer)
        }

        guard parseCount >= 2 else { return nil }

        var components = DateComponents()
        components.hour = Int(hour.pointee)
        components.minute = Int(minute.pointee)

        guard parseCount >= 3 else { return DatabaseDateComponents(components, format: .HM) }

        components.second = Int(second.pointee)

        guard parseCount >= 4 else { return DatabaseDateComponents(components, format: .HMS) }

        components.nanosecond = nanosecondsInt(for: nanosecond)

        return DatabaseDateComponents(components, format: .HMSS)
    }

    private static func nanosecondsInt(for nanoCString: UnsafePointer<CChar>) -> Int {
        let nanoString = "0." + String(cString: nanoCString)
        guard let doubleValue = Double(nanoString) else { return 0 }
        return Int(doubleValue * 1_000_000_000)
    }
}
