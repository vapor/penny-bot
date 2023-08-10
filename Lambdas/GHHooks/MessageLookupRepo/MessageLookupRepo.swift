
protocol MessageLookupRepo: Sendable {
    func getMessageID(repoID: Int, number: Int) async throws -> String
    func delete(repoID: Int, number: Int) async throws
    func markAsUnavailable(repoID: Int, number: Int) async throws
    func saveMessageID(messageID: String, repoID: Int, number: Int) async throws
}
