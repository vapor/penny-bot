
extension String {
    func foldForPings() -> String {
        self.lowercased()
    }
    
    func makePlainUserID() -> String {
        if self.hasPrefix("<@") && self.hasSuffix(">") {
            return String(self.dropFirst(2).dropLast())
        } else {
            return self
        }
    }
}
