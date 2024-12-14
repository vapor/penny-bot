extension User {
    package var isBot: Bool {
        self._type == "Bot"
    }
}

extension NullableUser {
    public var isBot: Bool {
        self._type == "Bot"
    }
}
