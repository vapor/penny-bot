@testable import PennyBOT
@testable import DiscordBM
@testable import PennyLambdaAddCoins
import SotoCore
import PennyRepositories
import Fake
import XCTest

class GatewayProcessingTests: XCTestCase {
    
    var manager: FakeManager { .shared }
    
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
        FakeManager.shared = FakeManager()
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
        let response = try await self.manager.sendAndAwaitResponse(
            key: .linkInteraction,
            endpoint: .editOriginalInteractionResponse(appId: "11111111", token: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw"),
            as: InteractionResponse.CallbackData.self
        )
        
        let description = try XCTUnwrap(response.embeds?.first?.description)
        XCTAssertEqual(description, "This command is still a WIP. Linking Discord with Discord ID 9123813923")
    }
    
    func testReactionHandler() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksReaction,
            endpoint: .postCreateMessage(channelId: "966722151359057950"),
            as: DiscordChannel.CreateMessage.self
        )
        
        let description = try XCTUnwrap(response.embeds?.first?.description)
        XCTAssertTrue(description.hasPrefix("""
        <@290483761559240704> gave a coin to <@1030118727418646629>!
        <@1030118727418646629> now has
        """))
        XCTAssertTrue(description.hasSuffix(" shiny coins."))
    }
}
