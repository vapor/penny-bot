public enum GitHubIDResponse: Sendable, Codable {
    case notLinked
    case id(String)
}
