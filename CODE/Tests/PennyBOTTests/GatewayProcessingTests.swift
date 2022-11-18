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
        await stateManager.tests_reset()
        await Penny.main()
        await manager.waitUntilConnected()
    }
    
    func testSlashCommandsRegisterOnStartup() async throws {
        let responses = await [
            responseStorage.awaitResponse(at: .createApplicationGlobalCommand(appId: "11111111")),
            responseStorage.awaitResponse(at: .createApplicationGlobalCommand(appId: "11111111"))
        ]
        
        let commandNames = ["link", "automated-pings"]
        
        for response in responses {
            let slashCommand = try XCTUnwrap(response as? ApplicationCommand)
            XCTAssertTrue(commandNames.contains(slashCommand.name), slashCommand.name)
        }
    }
    
    func testMessageHandler() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksMessage,
            as: RequestBody.CreateMessage.self
        )
        
        let description = try XCTUnwrap(response.embeds?.first?.description)
        XCTAssertTrue(description.hasPrefix("<@950695294906007573> now has "))
        XCTAssertTrue(description.hasSuffix(" coins!"))
    }
    
    func testInteractionHandler() async throws {
        let response = try await self.manager.sendAndAwaitResponse(
            key: .linkInteraction,
            as: RequestBody.InteractionResponse.CallbackData.self
        )
        
        let description = try XCTUnwrap(response.embeds?.first?.description)
        XCTAssertEqual(description, "This command is still a WIP. Linking Discord with Discord ID 9123813923")
    }
    
    func testReactionHandler() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksReaction,
            as: RequestBody.CreateMessage.self
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
        
        let message = try XCTUnwrap(response as? RequestBody.CreateMessage)
        XCTAssertGreaterThan(message.content?.count ?? -1, 20)
    }
    
    func testBotStateManagerReceivesSignal() async throws {
        await stateManager.tests_setDisableDuration(to: .seconds(3))
        
        let response = try await manager.sendAndAwaitResponse(
            key: .stopRespondingToMessages,
            as: RequestBody.CreateMessage.self
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
        let (createDM1, createDM2, sendDM1, sendDM2) = await (
            responseStorage.awaitResponse(at: event.responseEndpoints[0]),
            responseStorage.awaitResponse(at: event.responseEndpoints[1]),
            responseStorage.awaitResponse(at: event.responseEndpoints[2]),
            responseStorage.awaitResponse(at: event.responseEndpoints[3])
        )
        
        let recipients = ["4912300012398455", "21939123912932193"]
        
        do {
            let dmPayload = try XCTUnwrap(createDM1 as? RequestBody.CreateDM, "\(createDM1)")
            XCTAssertTrue(recipients.contains(dmPayload.recipient_id), dmPayload.recipient_id)
        }
        
        do {
            let dmPayload = try XCTUnwrap(createDM2 as? RequestBody.CreateDM, "\(createDM2)")
            XCTAssertTrue(recipients.contains(dmPayload.recipient_id), dmPayload.recipient_id)
        }
        
        do {
            let dmMessage = try XCTUnwrap(sendDM1 as? RequestBody.CreateMessage, "\(sendDM1)")
            let message = try XCTUnwrap(dmMessage.embeds?.first?.description)
            XCTAssertTrue(message.hasPrefix("There is a new message"), message)
        }
        
        do {
            let dmMessage = try XCTUnwrap(sendDM2 as? RequestBody.CreateMessage, "\(sendDM2)")
            let message = try XCTUnwrap(dmMessage.embeds?.first?.description)
            XCTAssertTrue(message.hasPrefix("There is a new message"), message)
        }
    }
}
