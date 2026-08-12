package enum LambdaResult<Success: Sendable & Codable>: Sendable, Codable {
    case success(Success)
    case failure(reason: String)
}
