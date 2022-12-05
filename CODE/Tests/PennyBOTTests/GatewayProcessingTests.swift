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
        Constants.botId = "1016612301262041098"
        LambdaHandlerStorage.coinLambdaHandlerType = FakeCoinLambdaHandler.self
        RepositoryFactory.makeUserRepository = { _ in
            FakeUserRepository()
        }
        Constants.coinServiceBaseUrl = "https://fake.com"
        ServiceFactory.makeCoinService = { _, _ in
            FakeCoinService()
        }
        // reset the storage
        FakeResponseStorage.shared = FakeResponseStorage()
        ReactionCache.tests_reset()
        self.manager = FakeManager()
        BotFactory.makeBot = { _, _ in self.manager! }
        // Due to how `Penny.main()` works, sometimes `Penny.main()` exits before
        // the fake manager is ready. That's why we need to use `waitUntilConnected()`.
        await stateManager.tests_reset()
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
            as: RequestBody.CreateMessage.self
        )
        
        let description = try XCTUnwrap(response.embeds?.first?.description)
        XCTAssertTrue(description.hasPrefix("<@950695294906007573> now has "))
        XCTAssertTrue(description.hasSuffix(" \(Constants.vaporCoinEmoji)!"))
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
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .thanksReaction,
                as: RequestBody.CreateMessage.self
            )
            
            let description = try XCTUnwrap(response.embeds?.first?.description)
            XCTAssertTrue(description.hasPrefix(
                "Mahdi BM gave a \(Constants.vaporCoinEmoji) to <@1030118727418646629>, who now has "
            ))
            XCTAssertTrue(description.hasSuffix(" \(Constants.vaporCoinEmoji)!"))
        }
        
        // For consistency with `testReactionHandler2()`
        try await Task.sleep(for: .seconds(1))
        
        // The second thanks message should just edit the last one, because the
        // receiver is the same person and the channel is the same channel.
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .thanksReaction2,
                as: RequestBody.EditMessage.self
            )
            
            let description = try XCTUnwrap(response.embeds?.first?.description)
            XCTAssertTrue(description.hasPrefix(
                "Mahdi BM & 0xTim gave 2 \(Constants.vaporCoinEmoji) to <@1030118727418646629>, who now has "
            ))
            XCTAssertTrue(description.hasSuffix(" \(Constants.vaporCoinEmoji)!"))
        }
    }
    
    func testReactionHandler2() async throws {
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .thanksReaction,
                as: RequestBody.CreateMessage.self
            )
            
            let description = try XCTUnwrap(response.embeds?.first?.description)
            XCTAssertTrue(description.hasPrefix(
                "Mahdi BM gave a \(Constants.vaporCoinEmoji) to <@1030118727418646629>, who now has "
            ))
            XCTAssertTrue(description.hasSuffix(" \(Constants.vaporCoinEmoji)!"))
        }
        
        // We need to wait a little bit to make sure Discord's response
        // is decoded and is used-in/added-to the `ReactionCache`.
        // This would happen in a real-world situation too.
        try await Task.sleep(for: .seconds(1))
        
        // Tell `ReactionCache` that someone sent a new message
        // in the same channel that the reaction happened.
        await ReactionCache.shared.invalidateCachesIfNeeded(
            event: .init(
                id: "1313",
                // Based on how the function works right now, only `channel_id` matters
                channel_id: "966722151359057911",
                content: "",
                timestamp: .fake,
                tts: false,
                mention_everyone: false,
                mentions: [],
                mention_roles: [],
                attachments: [],
                embeds: [],
                pinned: false,
                type: .default
            )
        )
        
        // The second thanks message should NOT edit the last one, because although the
        // receiver is the same person and the channel is the same channel, Penny's message
        // is not the last message anymore.
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .thanksReaction2,
                endpoint: EventKey.thanksReaction.responseEndpoints[0],
                as: RequestBody.CreateMessage.self
            )
            
            let description = try XCTUnwrap(response.embeds?.first?.description)
            XCTAssertTrue(description.hasPrefix(
                "0xTim gave a \(Constants.vaporCoinEmoji) to <@1030118727418646629>, who now has "
            ))
            XCTAssertTrue(description.hasSuffix(" \(Constants.vaporCoinEmoji)!"))
        }
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
}

private extension DiscordTimestamp {
    static let fake: DiscordTimestamp = {
        let string = #""2022-11-23T09:59:04.037259+00:00""#
        let data = Data(string.utf8)
        return try! JSONDecoder().decode(DiscordTimestamp.self, from: data)
    }()
}
