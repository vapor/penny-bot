@testable import GHHooksLambda
import DiscordModels

public struct FakeMessageLookupRepo: MessageLookupRepo {
    
    public init() { }

    public func getMessageID(repoID: Int, number: Int) async throws -> String {
        try AnySnowflake.makeFake().rawValue
    }

    public func saveMessageID(messageID: String, repoID: Int, number: Int) async throws { }
}
