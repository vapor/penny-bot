
extension String {
    public func urlPathEncoded() -> String {
        self.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? self
    }
}
