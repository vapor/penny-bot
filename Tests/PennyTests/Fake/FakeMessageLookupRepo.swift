@testable import GHHooksLambda
import DiscordModels

struct FakeMessageLookupRepo: MessageLookupRepo {

    static let randomMessageID: MessageSnowflake = try! .makeFake()

    init() { }

    func getMessageID(repoID: Int, number: Int) async throws -> String {
        Self.randomMessageID.rawValue
    }

    func markAsUnavailable(repoID: Int, number: Int) async throws { }

    func saveMessageID(messageID: String, repoID: Int, number: Int) async throws { }
}
