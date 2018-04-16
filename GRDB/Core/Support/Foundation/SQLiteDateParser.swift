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
    private static let nanosecond = UnsafeMutablePointer<Int32>.allocate(capacity: 1)

    public static func components(from dateString: String) -> DatabaseDateComponents? {
        switch dateString.count {
        case 23, 19, 16, 10:
            return datetimeComponents(from: dateString)
        case 12, 8, 5:
            return timeComponents(from: dateString)
        default:
            return nil
        }
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
            vsscanf(dateString, "%d-%d-%d%*c%d:%d:%d.%d", pointer)
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

        components.nanosecond = Int(nanosecond.pointee)

        return DatabaseDateComponents(components, format: .YMD_HMSS)
    }

    // - HH:MM
    // - HH:MM:SS
    // - HH:MM:SS.SSS
    private static func timeComponents(from timeString: String) -> DatabaseDateComponents? {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }

        let parseCount = withVaList([hour, minute, second, nanosecond]) { pointer in
            vsscanf(timeString, "%d:%d:%d.%d", pointer)
        }

        guard parseCount >= 2 else { return nil }

        var components = DateComponents()
        components.hour = Int(hour.pointee)
        components.minute = Int(minute.pointee)

        guard parseCount >= 3 else { return DatabaseDateComponents(components, format: .HM) }

        components.second = Int(second.pointee)

        guard parseCount >= 4 else { return DatabaseDateComponents(components, format: .HMS) }

        components.nanosecond = Int(nanosecond.pointee)

        return DatabaseDateComponents(components, format: .HMSS)
    }
}
