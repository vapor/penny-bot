
extension User {
    package var isBot: Bool {
        self._type == "Bot"
    }
}
