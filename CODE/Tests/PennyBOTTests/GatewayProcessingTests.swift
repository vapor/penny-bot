@testable import PennyBOT
@testable import DiscordBM
@testable import PennyLambdaAddCoins
import SotoCore
import PennyRepositories
import Fake
import XCTest

class GatewayProcessingTests: XCTestCase {
    
    var responseStorage: FakeResponseStorage { .shared }
    var manager: FakeManager!
    
    override func setUp() async throws {
        LambdaHandlerFactory.makeCoinLambdaHandler = { context in
            try await FakeCoinHandler(context: context)
        }
        RepositoryFactory.makeUserRepository = { _ in
            FakeUserRepository()
        }
        Constants.coinServiceBaseUrl = "https://fake.com"
        ServiceFactory.makeCoinService = { _, _ in
            FakeCoinService()
        }
        /// reset the storage
        FakeResponseStorage.shared = FakeResponseStorage()
        self.manager = FakeManager()
        BotFactory.makeBot = { _, _ in self.manager! }
        /// Due to how `Penny.main()` works, sometimes `Penny.main()` exits before the work
        /// is done and the fake manager is ready. That's why we need to do this.
        Task { await Penny.main() }
        await manager.waitUntilConnected()
    }
    
    func testSlashCommandsRegisterOnStartup() async throws {
        let response = await responseStorage.awaitResponse(
            at: .createApplicationGlobalCommand(appId: "11111111")
        )
        let slashCommand = try XCTUnwrap(response as? SlashCommand)
        XCTAssertEqual(slashCommand.name, "link")
    }
    
    func testMessageHandler() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksMessage,
            as: DiscordChannel.CreateMessage.self
        )
        
        let description = try XCTUnwrap(response.embeds?.first?.description)
        XCTAssertTrue(description.hasPrefix("<@950695294906007573> now has "))
        XCTAssertTrue(description.hasSuffix(" coins!"))
    }
    
    func testInteractionHandler() async throws {
        let response = try await self.manager.sendAndAwaitResponse(
            key: .linkInteraction,
            as: InteractionResponse.CallbackData.self
        )
        
        let description = try XCTUnwrap(response.embeds?.first?.description)
        XCTAssertEqual(description, "This command is still a WIP. Linking Discord with Discord ID 9123813923")
    }
    
    func testReactionHandler() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksReaction,
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
