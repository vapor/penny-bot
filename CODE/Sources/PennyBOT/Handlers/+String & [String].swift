import DiscordBM
import Foundation

extension StringProtocol {
    /// Removes leading and trailing whitespaces and
    /// Makes the string case, diacritic and punctuation insensitive.
    func foldForPingCommand() -> String {
        var substring = Substring(self)
        while substring.first?.isWhitespace == true {
            substring = substring.dropFirst()
        }
        while substring.last?.isWhitespace == true {
            substring = substring.dropLast()
        }
        let modified = substring
            .filter({ !$0.isPunctuation })
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
        return modified
    }
    
    func divideForPingCommandChecking() -> [[Substring]] {
        var substring = Substring(self)
        while substring.first?.isWhitespace == true {
            substring = substring.dropFirst()
        }
        while substring.last?.isWhitespace == true {
            substring = substring.dropLast()
        }
        let modified = substring
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .flatMap { $0.split(whereSeparator: \.isNewline) }
        
        let dividedByPuncs = modified.flatMap { $0.split(whereSeparator: \.isPunctuation) }
        
        return [modified, dividedByPuncs]
    }
}

extension [String] {
    func makeAutoPingsTextsList() -> String {
        self.sorted().enumerated().map { idx, text -> String in
            let escaped = DiscordUtils.escapingSpecialCharacters(text, forChannelType: .text)
            return "**\(idx + 1).** \(escaped)"
        }.joined(separator: "\n")
    }
    
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
