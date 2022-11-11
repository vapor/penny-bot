@testable import PennyBOT
@testable import DiscordBM
import PennyLambdaAddCoins
import PennyRepositories
import Fake
import XCTest

class GatewayProcessingTests: XCTestCase {
    
    var stateManager: BotStateManager { .shared }
    var responseStorage: FakeResponseStorage { .shared }
    var manager: FakeManager!
    
    override func setUp() async throws {
        DiscordGlobalConfiguration.enableLoggingDuringDecode = false
        Constants.botId = "1016612301262041098"
        LambdaHandlerStorage.coinLambdaHandlerType = FakeCoinLambdaHandler.self
        RepositoryFactory.makeUserRepository = { _ in
            FakeUserRepository()
        }
        RepositoryFactory.makeAutoPingsRepository = { _ in
            FakePingsRepository()
        }
        Constants.pingsServiceBaseUrl = "https://fake.com"
        ServiceFactory.makePingsService = {
            FakePingsService()
        }
        Constants.coinServiceBaseUrl = "https://fake2.com"
        ServiceFactory.makeCoinService = { _, _ in
            FakeCoinService()
        }
        /// reset the storage
        FakeResponseStorage.shared = FakeResponseStorage()
        self.manager = FakeManager()
        BotFactory.makeBot = { _, _ in self.manager! }
        await stateManager.tests_reset()
        /// Due to how `Penny.main()` works, sometimes `Penny.main()` exits before
        /// the fake manager is ready. That's why we need to use `waitUntilConnected()`.
        await Penny.main()
        await manager.waitUntilConnected()
    }
    
    func testSlashCommandsRegisterOnStartup() async throws {
        let response = await responseStorage.awaitResponse(
            at: .createApplicationGlobalCommand(appId: "11111111")
        )
        
        let slashCommand = try XCTUnwrap(response as? ApplicationCommand)
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
    
    func testBotStateManagerSendsSignalOnStartUp() async throws {
        let canRespond = await stateManager.canRespond
        XCTAssertEqual(canRespond, true)
        
        let response = await responseStorage.awaitResponse(
            at: .createMessage(channelId: Constants.internalChannelId)
        )
        
        let message = try XCTUnwrap(response as? DiscordChannel.CreateMessage)
        XCTAssertGreaterThan(message.content?.count ?? -1, 20)
    }
    
    func testBotStateManagerReceivesSignal() async throws {
        await stateManager.tests_setDisableDuration(to: .seconds(3))
        
        let response = try await manager.sendAndAwaitResponse(
            key: .stopRespondingToMessages,
            as: DiscordChannel.CreateMessage.self
        )
        
        XCTAssertGreaterThan(response.content?.count ?? -1, 20)
        
        // Wait to make sure BotStateManager has had enough time to process
        try await Task.sleep(for: .milliseconds(800))
        let testEvent = Gateway.Event(opcode: .dispatch)
        do {
            let canRespond = await stateManager.canRespond(to: testEvent)
            XCTAssertEqual(canRespond, false)
        }
        
        // After 3 seconds, the state manager should allow responses again, because
        // `BotStateManager.disableDuration` has already been passed
        try await Task.sleep(for: .milliseconds(2600))
        do {
            let canRespond = await stateManager.canRespond(to: testEvent)
            XCTAssertEqual(canRespond, true)
        }
    }
    
    func testAutoPings() async throws {
        let event = EventKey.autoPingsTrigger
        try await manager.send(key: event)
        let (createDM, sendDM) = await (
            responseStorage.awaitResponse(at: event.responseEndpoints[0]),
            responseStorage.awaitResponse(at: event.responseEndpoints[1])
        )
        let dmPayload = try XCTUnwrap(createDM as? RequestBody.CreateDM, "\(createDM)")
        XCTAssertEqual(dmPayload.recipient_id, "4912300012398455")
        
        let dmMessage = try XCTUnwrap(sendDM as? DiscordChannel.CreateMessage, "\(sendDM)")
        let message = try XCTUnwrap(dmMessage.embeds?.first?.description)
        XCTAssertTrue(message.hasPrefix("There is a new message"), message)
    }
}
