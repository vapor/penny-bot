
extension User {
    public var isBot: Bool {
        self._type == "Bot"
    }
}
