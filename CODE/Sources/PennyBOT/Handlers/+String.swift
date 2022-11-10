
extension String {
    func foldForPingCommand() -> String {
        self.lowercased()
    }
    
    /// Turns ids like `<@12012020120>` to plain `12012020120` if needed.
    func makePlainUserID() -> String {
        if self.hasPrefix("<@") && self.hasSuffix(">") {
            return String(self.dropFirst(2).dropLast())
        } else {
            return self
        }
    }
}
