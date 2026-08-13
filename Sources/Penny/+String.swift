import Models
import Shared

/// `StringProtocol` is basically either `String` or `Substring`.
extension StringProtocol {
    /// Trims whitespaces and makes the string case, diacritic and punctuation insensitive.
    func heavyFolded() -> String {
        self.trimmingWhitespaces()
            .removingOccurrences(where: \.isPunctuation)
            .lowercased()
            .foldingDiacritics()
    }

    /// No whitespaces or lines and makes the string case, diacritic and punctuation insensitive.
    func superHeavyFolded() -> String {
        self.lowercased()
            .filter { !($0.isWhitespace || $0.isNewline || $0.isPunctuation) }
            .foldingDiacritics()
    }

    func divideForPingCommandExactMatchChecking() -> [[Substring]] {
        let modified = self.trimmingWhitespaces()
            .lowercased()
            .foldingDiacritics()
            .split(whereSeparator: \.isWhitespaceOrNewline)

        let dividedByPuncs = modified.flatMap { $0.split(whereSeparator: \.isPunctuation) }

        return [modified, dividedByPuncs]
    }

    func foldedForPingCommandContainmentChecking() -> String {
        self.trimmingWhitespaces()
            .lowercased()
            .foldingDiacritics()
    }

    /// Removes any occurrences of the characters that the predicate matches.
    func removingOccurrences(where shouldRemove: (Character) -> Bool) -> String {
        /// Nothing to remove is the common case, so don't allocate for it.
        guard self.contains(where: shouldRemove) else {
            return String(self)
        }

        return String(self.filter { !shouldRemove($0) })
    }
}

extension Array where Element: StringProtocol {
    func containsSequence(_ other: Self) -> Bool {
        if other.count > self.count { return false }

        for idx in 0..<(self.count - other.count + 1) {
            if self[idx..<idx + other.count].elementsEqual(other) {
                return true
            }
        }

        return false
    }
}

extension Character {
    fileprivate var isWhitespaceOrNewline: Bool {
        self.isWhitespace || self.isNewline
    }
}
