import DiscordModels

@testable import GHHooksLambda

public struct FakeMessageLookupRepo: MessageLookupRepo {

    public static let randomMessageID: MessageSnowflake = try! .makeFake()

    public init() {}

    public func getMessageID(repoID: Int, number: Int) async throws -> String {
        Self.randomMessageID.rawValue
    }

    public func delete(repoID: Int, number: Int) async throws {}

    public func markAsUnavailable(repoID: Int, number: Int) async throws {}

    public func saveMessageID(messageID: String, repoID: Int, number: Int) async throws {}
}
