public enum AuthorizationHeader: Sendable {
    /// The `Bool` is `isRetry`.
    public typealias BearerComputer = @Sendable (Bool) async throws -> String

    case bearer(String)
    case computedBearer(BearerComputer)
    case none

    var isRetriable: Bool {
        switch self {
        case .bearer, .none:
            return false
        case .computedBearer:
            return true
        }
    }

    func makeHeader(isRetry: Bool = false) async throws -> String? {
        switch self {
        case let .bearer(token):
            return "Bearer \(token)"
        case let .computedBearer(computer):
            let token = try await computer(isRetry)
            return "Bearer \(token)"
        case .none:
            return nil
        }
    }
}
