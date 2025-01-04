import DiscordModels

@testable import GHHooksLambda

struct FakeMessageLookupRepo: MessageLookupRepo {

    static let randomMessageID: MessageSnowflake = try! .makeFake()

    init() {}

    func getMessageID(repoID: Int64, number: Int) async throws -> String {
        Self.randomMessageID.rawValue
    }

    func markAsUnavailable(repoID: Int64, number: Int) async throws {}

    func saveMessageID(messageID: String, repoID: Int64, number: Int) async throws {}
}
