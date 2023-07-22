public enum AuthorizationHeader: Sendable {
    /// The `Bool` is `isRetry`.
    public typealias CustomHeaderCalculator = @Sendable (Bool) async throws -> String

    case bearer(String)
    case custom(CustomHeaderCalculator)
    case none

    var isRetriable: Bool {
        switch self {
        case .bearer, .none:
            return false
        case .custom:
            return true
        }
    }

    func makeHeader(isRetry: Bool = false) async throws -> String? {
        switch self {
        case let .bearer(token):
            return "Bearer \(token)"
        case let .custom(customBlock):
            let token = try await customBlock(isRetry)
            return "Bearer \(token)"
        case .none:
            return nil
        }
    }
}
