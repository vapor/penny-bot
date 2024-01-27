@testable import GHHooksLambda
import DiscordModels

package struct FakeMessageLookupRepo: MessageLookupRepo {

    package static let randomMessageID: MessageSnowflake = try! .makeFake()

    package init() { }

    package func getMessageID(repoID: Int, number: Int) async throws -> String {
        Self.randomMessageID.rawValue
    }

    package func markAsUnavailable(repoID: Int, number: Int) async throws { }

    package func saveMessageID(messageID: String, repoID: Int, number: Int) async throws { }
}
