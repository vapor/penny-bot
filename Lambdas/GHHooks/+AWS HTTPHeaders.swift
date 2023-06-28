import AWSLambdaEvents

extension AWSLambdaEvents.HTTPHeaders {
    /// Case-sensitive.
    /// Github Docs shows header names as capitalized, but they are actually sent as lowercased.
    public func first(name: String) -> String? {
        return self.first { $0.key == name }?.value
    }
}
