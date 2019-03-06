import Foundation

extension String {
    var uppercasingFirstCharacter: String {
        guard let first = first else {
            return self
        }
        return String(first).uppercased() + dropFirst()
    }
}
