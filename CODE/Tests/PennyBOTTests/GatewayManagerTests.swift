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
        RepositoryFactory.makeUserRepository = { _ in
            FakeUserRepository()
        }
        ServiceFactory.makeCoinService = { _, _ in
            FakeCoinService()
        }
        try await Penny.main()
    }
    
    func testMessageHandler() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksMessage,
            endpoint: .postCreateMessage(channelId: "441327731486097429"),
            as: DiscordChannel.CreateMessage.self
        )
        let description = try XCTUnwrap(response.embeds?.first?.description)
        XCTAssertTrue(description.hasPrefix("<@950695294906007573> now has "))
        XCTAssertTrue(description.hasSuffix(" coins!"))
    }
}
