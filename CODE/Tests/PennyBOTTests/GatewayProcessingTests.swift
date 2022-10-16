@testable import PennyBOT
@testable import DiscordBM
@testable import PennyLambdaAddCoins
import SotoCore
import PennyRepositories
import Fake
import XCTest

class GatewayProcessingTests: XCTestCase {
    
    let manager = FakeManager.shared
    
    override func setUp() async throws {
        Constants.coinServiceBaseUrl = "https://fake.com"
        BotFactory.makeBot = { _, _ in FakeManager.shared }
        AWSClientFactory.makeClient = { 
            AWSClient(httpClientProvider: .shared(
                FakeAWSHTTPClient(eventLoopGroup: $0)
            ))
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
    
    func testInteractionHandler() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .linkInteraction,
            endpoint: .createInteractionResponse(id: "1018162735864872971", token: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw"),
            as: InteractionResponse.self
        )
        
        let description = try XCTUnwrap(response.data?.embeds?.first?.description)
        XCTAssertTrue(description.hasPrefix("<@950695294906007573> now has "))
        XCTAssertTrue(description.hasSuffix(" coins!"))
    }
    
    func testReactionHandler() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksReaction,
            endpoint: .postCreateMessage(channelId: "441327731486097429"),
            as: InteractionResponse.self
        )
        
        let description = try XCTUnwrap(response.data?.embeds?.first?.description)
        XCTAssertTrue(description.hasPrefix("<@950695294906007573> now has "))
        XCTAssertTrue(description.hasSuffix(" coins!"))
    }
}
