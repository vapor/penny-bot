import DiscordBM
import Foundation

extension StringProtocol {
    /// Removes leading and trailing whitespaces and
    /// Makes the string case, diacritic and punctuation insensitive.
    func foldForPingCommand() -> String {
        self.trimmingCharacters(in: .whitespaces)
            .removingOccurrences(of: .punctuationCharacters)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
    }
    
    func divideForPingCommandChecking() -> [[Substring]] {
        let modified = self.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .split(whereSeparator: \.isWhitespaceOrNewline)
        
        let dividedByPuncs = modified.flatMap { $0.split(whereSeparator: \.isPunctuation) }
        
        return [modified, dividedByPuncs]
    }
}

extension String {
    /// Remove any occurrences of the characters in the character-set.
    func removingOccurrences(of target: CharacterSet) -> String {
        var scalars = self.unicodeScalars
        
        var remove = ContiguousArray<String.Index>()
        
        for idx in scalars.indices {
            if target.contains(scalars[idx]) {
                let removeAt = scalars.index(idx, offsetBy: -remove.count)
                remove.append(removeAt)
            }
        }
        
        for idx in remove {
            scalars.remove(at: idx)
        }
        
        return String(scalars)
    }
}

extension Sequence<String> {
    func makeSortedEnumeratedListForDiscord() -> String {
        self.sorted().makeEnumeratedListForDiscord()
    }
    
    func makeEnumeratedListForDiscord() -> String {
        self.enumerated().map { idx, text -> String in
            let escaped = DiscordUtils.escapingSpecialCharacters(text, forChannelType: .text)
            return "**\(idx + 1).** \(escaped)"
        }.joined(separator: "\n")
    }
}

extension [String] {
    func divide(
        _ isInLhs: (Element) async throws -> Bool
    ) async rethrows -> (lhs: Self, rhs: Self) {
        var lhs = ContiguousArray<Element>()
        var rhs = ContiguousArray<Element>()
        
        var iterator = self.makeIterator()
        
        while let element = iterator.next() {
            if try await isInLhs(element) {
                lhs.append(element)
            } else {
                rhs.append(element)
            }
        }
        
        return (Array(lhs), Array(rhs))
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
