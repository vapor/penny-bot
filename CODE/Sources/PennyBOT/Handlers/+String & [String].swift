import DiscordBM

extension StringProtocol {
    func foldForPingCommand() -> String {
        var substring = Substring(self)
        while substring.first?.isWhitespace == true {
            substring = substring.dropFirst()
        }
        while substring.last?.isWhitespace == true {
            substring = substring.dropLast()
        }
        let modified = substring
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
        return String(modified)
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
