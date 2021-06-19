/// A case-preserving, case-insensitive identifier
/// that matches the ASCII version of sqlite3_stricmp
struct CaseInsensitiveIdentifier: Hashable {
    private let lowercased: String
    let rawValue: String
    
    init(rawValue: String) {
        self.lowercased = rawValue.lowercased()
        self.rawValue = rawValue
    }
    
    static func == (lhs: CaseInsensitiveIdentifier, rhs: CaseInsensitiveIdentifier) -> Bool {
        lhs.lowercased == rhs.lowercased
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(lowercased)
    }
}
