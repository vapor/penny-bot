
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
