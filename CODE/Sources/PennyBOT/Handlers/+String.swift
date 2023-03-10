
extension StringProtocol {
    func foldForPingCommand() -> String {
        var lowercased = Substring(self.lowercased())
        while lowercased.first?.isWhitespace == true {
            lowercased = lowercased.dropFirst()
        }
        while lowercased.last?.isWhitespace == true {
            lowercased = lowercased.dropLast()
        }
        return String(lowercased.folding(options: .diacriticInsensitive, locale: nil))
    }
}
