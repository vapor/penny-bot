@testable import PennyBOT
@testable import DiscordBM
@testable import PennyLambdaAddCoins
import SotoCore
import PennyRepositories
import Fake
import XCTest

class GatewayManagerTests: XCTestCase {
    
    let manager = FakeManager.shared
    
    override func setUp() async throws {
        Constants.coinServiceBaseUrl = "https://fake.com"
        BotFactory.makeBot = { _, _ in FakeManager.shared }
        AWSClientFactory.makeClient = { 
            AWSClient(httpClientProvider: .shared(FakeAWSHTTPClient(eventLoopGroup: $0)))
        }
        RepositoryFactory.makeUserRepository = {
            FakeUserRepository(
                db: $0.db,
                tableName: $0.tableName,
                eventLoop: $0.eventLoop,
                logger: $0.logger
            )
        }
        try await Penny.main()
    }
    
    func testSomething() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksMessage,
            endpoint: .postCreateMessage(channelId: "441327731486097429"),
            as: DiscordChannel.CreateMessage.self
        )
        let description = try XCTUnwrap(response.embeds?.first?.description)
        XCTAssertEqual(description, "")
    }
}
