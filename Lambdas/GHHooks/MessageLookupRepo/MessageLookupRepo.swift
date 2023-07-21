
protocol MessageLookupRepo {
    func getMessageID(repoID: Int, number: Int) async throws -> String
    func saveMessageID(messageID: String, repoID: Int, number: Int) async throws
}
