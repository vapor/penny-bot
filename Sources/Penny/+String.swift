import Foundation
import Models

extension String {
    func unicodesPrefix(_ maxUnicodeScalars: Int) -> String {
        assert(maxUnicodeScalars >= 0, "Can request a negative maximum.")

        // Take a prefix of the string (i.e. a sequence of extended grapheme clusters) first.
        // Most of the time, this will already be short enough.
        var trimmed = self.prefix(maxUnicodeScalars)

        // If the result still has too many unicode scalars, there're one or more grapheme
        // clusters in the string. Keep dropping extended grapheme clusters off the end (which
        // with `String` is as easy as just removing the last `Character`) until we're within
        // bounds. Worst-case complexity is `O(n)`.
        while trimmed.unicodeScalars.count > maxUnicodeScalars {
            trimmed.removeLast()
        }

        return String(trimmed)
    }
}

/// `StringProtocol` is basically either `String` or `Substring`.
extension StringProtocol {
    /// trims whitespaces and makes the string case, diacritic and punctuation insensitive.
    func heavyFolded() -> String {
        self.trimmingCharacters(in: .whitespaces)
            .removingOccurrences(of: .punctuationCharacters)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
    }
    
    func divideForPingCommandExactMatchChecking() -> [[Substring]] {
        let modified = self.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .split(whereSeparator: \.isWhitespaceOrNewline)
        
        let dividedByPuncs = modified.flatMap { $0.split(whereSeparator: \.isPunctuation) }
        
        return [modified, dividedByPuncs]
    }
    
    func foldedForPingCommandContainmentChecking() -> String {
        self.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
    }
}

extension String {
    /// Removes any occurrences of the characters in the character-set.
    func removingOccurrences(of target: CharacterSet) -> String {
        /// Couldn't make it properly work without copy-ing the string
        /// into an array and by only using `String.Index`
        var copy = Array(self)
        
        var remove = [Int]()
        
        for idx in copy.indices {
            if  copy[idx].unicodeScalars.contains(where: { target.contains($0) }) {
                let removeAt = copy.index(idx, offsetBy: -remove.count)
                remove.append(removeAt)
            }
        }
        
        for idx in remove {
            copy.remove(at: idx)
        }
        
        return String(copy)
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

private extension Character {
    var isWhitespaceOrNewline: Bool {
        self.isWhitespace || self.isNewline
    }
}
