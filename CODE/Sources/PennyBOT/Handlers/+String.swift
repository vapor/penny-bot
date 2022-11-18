
extension String {
    func foldForPingCommand() -> String {
        var lowercased = Substring(self.lowercased())
        while lowercased.first?.isWhitespace == true {
            lowercased = lowercased.dropFirst()
        }
        while lowercased.last?.isWhitespace == true {
            lowercased = lowercased.dropLast()
        }
        return String(lowercased)
    }
    
    /// Turns ids like `<@12012020120>` to plain `12012020120` if they are not already like that.
    func makePlainUserID() -> String {
        if self.hasPrefix("<@") && self.hasSuffix(">") {
            return String(self.dropFirst(2).dropLast())
        } else {
            return self
        }
    }
}
