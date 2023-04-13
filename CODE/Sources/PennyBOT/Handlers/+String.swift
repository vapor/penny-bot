import DiscordBM
import Foundation
import PennyModels

/// `StringProtocol` is basically either `String` or `Substring`.
extension StringProtocol {
    /// trims whitespaces and makes the string case, diacritic and punctuation insensitive.
    func foldForPingCommand() -> String {
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
        
        var remove = ContiguousArray<Int>()
        
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

extension Sequence<String> {
    func makeEnumeratedListForDiscord(leadingSpacesLength: Int = 0) -> String {
        let spaces = String(repeating: " ", count: leadingSpacesLength)
        return self.enumerated().map { idx, text -> String in
            let escaped = DiscordUtils.escapingSpecialCharacters(text, forChannelType: .text)
            return "\(spaces)**\(idx + 1).** \(escaped)"
        }.joined(separator: "\n")
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
