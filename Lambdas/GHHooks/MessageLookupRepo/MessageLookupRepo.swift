protocol MessageLookupRepo: Sendable {
    func getMessageID(repoID: Int64, number: Int) async throws -> String
    func markAsUnavailable(repoID: Int64, number: Int) async throws
    func saveMessageID(messageID: String, repoID: Int64, number: Int) async throws
}
