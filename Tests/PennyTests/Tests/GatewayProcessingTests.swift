@testable import Penny
@testable import DiscordModels
@testable import Logging
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DiscordGateway
import ServiceLifecycle
import Models
import Shared
import Testing

extension SerializationNamespace {
    @Suite
    final class GatewayProcessingTests: Sendable {
        var responseStorage: FakeResponseStorage { .shared }
        let manager = FakeManager()
        let fakeMainService: FakeMainService
        let context: HandlerContext
        let mainServiceTask: Task<Void, any Error>

        init() async throws {
            /// Simulate prod
            setenv("DEPLOYMENT_ENVIRONMENT", "prod", 1)
            /// Disable logging
            LoggingSystem.bootstrapInternal(SwiftLogNoOpLogHandler.init)
            /// First reset the background runner
            BackgroundProcessor.sharedForTests = BackgroundProcessor()
            /// Then reset the storage
            FakeResponseStorage.shared = FakeResponseStorage()
            let fakeMainService = try await FakeMainService(manager: self.manager)
            self.fakeMainService = fakeMainService
            self.context = fakeMainService.context
            mainServiceTask = Task<Void, any Error> {
                try await Penny.start(mainService: fakeMainService)
            }
            await fakeMainService.waitForStateManagerShutdownAndDidShutdownSignals()
        }

        deinit {
            mainServiceTask.cancel()
        }
    }
}

extension SerializationNamespace.GatewayProcessingTests {
    @Test
    func waiterServiceRunsUnderlyingService() async throws {
        actor SampleService: Service {
            var didRun = false
            func run() async throws {
                self.didRun = true
            }
        }

        let sampleService = SampleService()

        let wrappedService = WaiterService(
            underlyingService: sampleService,
            processingOn: context.backgroundProcessor,
            passingContinuationWith: { await self.context.botStateManager.addCachesPopulationWaiter($0) }
        )

        try await wrappedService.run()

        #expect(await sampleService.didRun == true)
    }

    @Test
    func waiterServiceWaitsForUnderlyingService() async throws {
        actor SampleService: Service {
            var didRun = false
            func run() async throws {
                self.didRun = true
            }
        }

        let sampleService = SampleService()

        let wrappedService = WaiterService(
            underlyingService: sampleService,
            processingOn: context.backgroundProcessor,
            passingContinuationWith: { _ in /* Do nothing */ }
        )

        let runningService = Task {
            try await wrappedService.run()
        }

        try await Task.sleep(for: .seconds(5))

        runningService.cancel()

        #expect(await sampleService.didRun == false)
    }

    @Test
    func commandsRegisterOnStartup() async throws {
        await CommandsManager(context: context).registerCommands()
        
        let response = await responseStorage.awaitResponse(
            at: .bulkSetApplicationCommands(applicationId: "11111111")
        ).value
        
        let commandNames = SlashCommand.allCases.map(\.rawValue)
        let commands = try #require(response as? [Payloads.ApplicationCommandCreate])
        #expect(commands.map(\.name).sorted() == commandNames.sorted())
    }
    
    @Test
    func messageHandler() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksMessage,
            as: Payloads.CreateMessage.self
        )
        
        let description = try #require(response.embeds?.first?.description)
        #expect(description.hasPrefix("<@950695294906007573> now has "), "\(description)")
        #expect(description.hasSuffix(" \(Constants.ServerEmojis.coin.emoji)!"), "\(description)")
    }
    
    @Test
    func reactionHandler() async throws {
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .thanksReaction,
                as: Payloads.CreateMessage.self
            )
            
            let description = try #require(response.embeds?.first?.description)
            #expect(description.hasPrefix(
                "Mahdi BM gave a \(Constants.ServerEmojis.coin.emoji) to <@1030118727418646629>, who now has "
            ), "\(description)")
            #expect(description.hasSuffix(" \(Constants.ServerEmojis.coin.emoji)!"))
        }
        
        // For consistency with `testReactionHandler2()`
        try await Task.sleep(for: .seconds(1))
        
        // The second thanks message should just edit the last one, because the
        // receiver is the same person and the channel is the same channel.
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .thanksReaction2,
                as: Payloads.EditMessage.self
            )
            
            let description = try #require(response.embeds?.first?.description)
            #expect(description.hasPrefix(
                "Mahdi BM & 0xTim gave 2 \(Constants.ServerEmojis.coin.emoji) to <@1030118727418646629>, who now has "
            ))
            #expect(description.hasSuffix(" \(Constants.ServerEmojis.coin.emoji)!"))
        }
    }

    @Test
    func reactionHandler3() async throws {
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .thanksReaction3,
                as: Payloads.CreateMessage.self
            )
            
            let description = try #require(response.embeds?.first?.description)
            #expect(description.hasPrefix("""
            0xTim gave a \(Constants.ServerEmojis.coin.emoji) to <@1030118727418646629>, who now has
            """), "\(description)")
            #expect(description.hasSuffix("""
            \(Constants.ServerEmojis.coin.emoji)! (https://discord.com/channels/431917998102675485/431926479752921098/1031112115928442034)
            """), "\(description)")
        }
        
        // We need to wait a little bit to make sure Discord's response
        // is decoded and is used-in/added-to the `ReactionCache`.
        // This would happen in a real-world situation too.
        try await Task.sleep(for: .seconds(1))
        
        // The second thanks message should edit the last one.
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .thanksReaction4,
                as: Payloads.EditMessage.self
            )
            
            let description = try #require(response.embeds?.first?.description)
            #expect(description.hasPrefix("""
            0xTim & Mahdi BM gave 2 \(Constants.ServerEmojis.coin.emoji) to <@1030118727418646629>, who now has
            """), "\(description)")
            #expect(description.hasSuffix("""
            \(Constants.ServerEmojis.coin.emoji)! (https://discord.com/channels/431917998102675485/431926479752921098/1031112115928442034)
            """))
        }
    }
    
    @Test
    func respondsInThanksChannelWhenDoesNotHavePermission() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksMessage2,
            as: Payloads.CreateMessage.self
        )
        
        let description = try #require(response.embeds?.first?.description)
        
        #expect(description.hasPrefix("<@950695294906007573> now has "), "\(description)")
        let expectedSuffix = """
        \(Constants.ServerEmojis.coin.emoji)! (https://discord.com/channels/431917998102675485/431917998102675487/1029637770005717042)
        """
        #expect(description.hasSuffix(expectedSuffix), "\(description)")
    }
    
    @Test
    func botStateManagerReceivesSignal() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .stopRespondingToMessages,
            as: Payloads.CreateMessage.self
        )
        
        #expect(response.content?.count ?? -1 > 20)
        
        // Wait to make sure BotBotStateManager.shared has had enough time to process
        try await Task.sleep(for: .milliseconds(800))
        let testEvent = Gateway.Event(opcode: .dispatch)
        do {
            let canRespond = await context.botStateManager.canRespond(to: testEvent)
            #expect(canRespond == false)
        }
        
        // After 3 seconds, the state manager should allow responses again, because
        // `BotBotStateManager.shared.disableDuration` has already been passed
        try await Task.sleep(for: .milliseconds(2600))
        do {
            let canRespond = await context.botStateManager.canRespond(to: testEvent)
            #expect(canRespond == true)
        }
    }
    
    @Test
    func autoPings() async throws {
        let event = EventKey.autoPingsTrigger
        await manager.send(key: event)
        let createDMEndpoint = event.responseEndpoints[0]
        let responseEndpoint = event.responseEndpoints[1]
        let (createDM1, createDM2, sendDM1, sendDM2) = await (
            responseStorage.awaitResponse(at: createDMEndpoint).value,
            responseStorage.awaitResponse(at: createDMEndpoint).value,
            responseStorage.awaitResponse(at: responseEndpoint).value,
            responseStorage.awaitResponse(at: responseEndpoint).value
        )
        
        let recipients: [UserSnowflake] = ["950695294906007573", "432065887202181142"]
        
        do {
            let dmPayload = try #require(createDM1 as? Payloads.CreateDM, "\(createDM1)")
            #expect(recipients.contains(dmPayload.recipient_id), "\(dmPayload.recipient_id)")
        }
        
        let dmMessage1 = try #require(sendDM1 as? Payloads.CreateMessage, "\(sendDM1)")
        let message1 = try #require(dmMessage1.embeds?.first?.description)
        #expect(message1.hasPrefix("There is a new message"), "\(message1)")
        /// Check to make sure the expected ping-words are mentioned in the message
        #expect(message1.contains("- mongodb driver"), "\(message1)")

        do {
            /// These two must not fail. The user does not have any
            /// significant roles but they still should receive the pings.
            let dmPayload = try #require(createDM2 as? Payloads.CreateDM, "\(createDM1)")
            #expect(recipients.contains(dmPayload.recipient_id), "\(dmPayload.recipient_id)")
        }
        
        let dmMessage2 = try #require(sendDM2 as? Payloads.CreateMessage, "\(sendDM1)")
        let message2 = try #require(dmMessage2.embeds?.first?.description)
        #expect(message2.hasPrefix("There is a new message"), "\(message2)")
        /// Check to make sure the expected ping-words are mentioned in the message
        #expect(message2.contains("- mongodb driver"), "\(message2)")

        /// Contains `godb dr` (part of `mongodb driver`).
        /// Tests `Expression.contain("godb dr")`.
        #expect(
            [message1, message2].contains(where: { $0.contains("- godb dr") }),
            #"None of the 2 payloads contained "godb dr". Messages: \#([message1, message2]))"#
        )
        
        #expect(message2.hasSuffix(">>> need help with some MongoDB Driver"), "\(message2)")

        let event2 = EventKey.autoPingsTrigger2
        let createDMEndpoint2 = event2.responseEndpoints[0]
        let responseEndpoint2 = event2.responseEndpoints[1]
        await manager.send(key: event2)
        let (createDM, sendDM) = await (
            responseStorage.awaitResponse(at: createDMEndpoint2, expectFailure: true).value,
            responseStorage.awaitResponse(at: responseEndpoint2).value
        )
        
        /// The DM channel has already been created for the last tests,
        /// so should not be created again since it should have been cached.
        do {
            let payload: Never? = try #require(createDM as? Optional<Never>)
            #expect(payload == .none)
        }
        
        do {
            let dmMessage = try #require(sendDM as? Payloads.CreateMessage, "\(sendDM)")
            let message = try #require(dmMessage.embeds?.first?.description)
            #expect(message.hasPrefix("There is a new message"), "\(message)")
            /// Check to make sure the expected ping-words are mentioned in the message
            #expect(message.contains("- blog"), "\(message)")
            #expect(message.contains("- discord"), "\(message)")
            #expect(message.contains("- discord-kit"), "\(message)")
            #expect(message.contains("- cord"), "\(message)")

            #expect(message.hasSuffix(">>> I want to use the discord-kit library\nhttps://www.swift.org/blog/swift-certificates-and-asn1/"), "\(message)")
        }
    }
    
    @Test
    func howManyCoins() async throws {
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .howManyCoins1,
                as: Payloads.EditWebhookMessage.self
            )
            let message = try #require(response.embeds?.first?.description)
            #expect(message == "<@290483761559240704> has 2591 \(Constants.ServerEmojis.coin.emoji)!")
        }
        
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .howManyCoins2,
                as: Payloads.EditWebhookMessage.self
            )
            let message = try #require(response.embeds?.first?.description)
            #expect(message == "<@961607141037326386> has 2591 \(Constants.ServerEmojis.coin.emoji)!")
        }
    }
    
    @Test
    func serverBoostCoins() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .serverBoost,
            as: Payloads.CreateMessage.self
        )
        #expect(response.content == "<@432065887202181142>")
        let description = try #require(response.embeds?.first?.description)
        #expect(
            description.hasPrefix(
                """
                Thanks for the Server Boost \(Constants.ServerEmojis.love.emoji)!
                You now have 10 more \(Constants.ServerEmojis.coin.emoji) for a total of
                """
            )
        )
        #expect(description.hasSuffix(" \(Constants.ServerEmojis.coin.emoji)!"))
    }
    
    @Test
    func evolutionChecker() async throws {
        /// This tests expects the `CachesStorage` population to have worked correctly
        /// and have already populated `EvolutionChecker.previousProposals`.

        /// This is so the proposals are send as soon as they're queued, in tests.
        let serviceTask = Task<Void, any Error> { [self] in
            try await self.context.evolutionChecker.run()
        }


        let endpoint = APIEndpoint.createMessage(channelId: Constants.Channels.evolution.id)
        let _messages = await [
            self.responseStorage.awaitResponse(at: endpoint).value,
            self.responseStorage.awaitResponse(at: endpoint).value
        ]
        let messages = try _messages.map {
            try #require($0 as? Payloads.CreateMessage, "\($0), messages: \(_messages)")
        }

        /// New proposal message
        do {
            let message = try #require(messages.first(where: {
                $0.embeds?.first?.title?.contains("stride") == true
            }), "\(messages)")

            #expect(message.embeds?.first?.url == "https://github.com/apple/swift-evolution/blob/main/proposals/0051-stride-semantics.md")

            let buttons = try #require(message.components?.first?.components, "\(message)")
            #expect(buttons.count == 2, "\(buttons)")
            let expectedLinks = [
                "https://forums.swift.org/t/accepted-se-0400-init-accessors/66212",
                "https://forums.swift.org/search?q=Conventionalizing%20stride%20semantics%20%23evolution"
            ]
            for (idx, buttonComponent) in buttons.enumerated() {
                if let url = try buttonComponent.requireButton().url {
                    #expect(expectedLinks[idx] == url)
                } else {
                    Issue.record("\(buttonComponent) was not a button")
                }
            }

            let embed = try #require(message.embeds?.first)
            #expect(embed.title == "[SE-0051] Withdrawn: Conventionalizing stride semantics")
            #expect(embed.description == "> \n**Status: Withdrawn**\n\n**Author(s):** [Erica Sadun](http://github.com/erica)\n")
            #expect(embed.color == .brown)
        }

        /// Updated proposal message
        do {
            let message = try #require(messages.first(where: {
                $0.embeds?.first?.title?.contains("(most)") == true
            }), "\(messages)")

            #expect(message.embeds?.first?.url == "https://github.com/apple/swift-evolution/blob/main/proposals/0001-keywords-as-argument-labels.md")

            let buttons = try #require(message.components?.first?.components)
            #expect(buttons.count == 2, "\(buttons)")
            let expectedLinks = [
                "https://forums.swift.org/t/accepted-se-0400-init-accessors/66212",
                "https://forums.swift.org/search?q=Allow%20(most)%20keywords%20as%20argument%20labels%20%23evolution"
            ]
            for (idx, buttonComponent) in buttons.enumerated() {
                if let url = try buttonComponent.requireButton().url {
                    #expect(expectedLinks[idx] == url)
                } else {
                    Issue.record("\(buttonComponent) was not a button")
                }
            }

            let embed = try #require(message.embeds?.first)
            #expect(embed.title == "[SE-0001] In Active Review: Allow (most) keywords as argument labels")
            #expect(embed.description == "> Argument labels are an important part of the interface of a Swift function, describing what particular arguments to the function do and improving readability. Sometimes, the most natural label for an argument coincides with a language keyword, such as `in`, `repeat`, or `defer`. Such keywords should be allowed as argument labels, allowing better expression of these interfaces.\n**Status:** Implemented -> **Active Review**\n\n**Author(s):** [Doug Gregor](https://github.com/DougGregor)\n")
            #expect(embed.color == .orange)
        }

        serviceTask.cancel()
    }
    
    @Test
    func soChecker() async throws {
        let serviceTask = Task<Void, any Error> { [self] in
            try await self.context.soChecker.run()
        }

        let endpoint = APIEndpoint.createMessage(channelId: Constants.Channels.stackOverflow.id)
        let _messages = await [
            self.responseStorage.awaitResponse(at: endpoint).value,
            self.responseStorage.awaitResponse(at: endpoint).value,
            self.responseStorage.awaitResponse(at: endpoint).value,
            self.responseStorage.awaitResponse(at: endpoint).value,
        ]
        let messages = try _messages.map {
            try #require($0 as? Payloads.CreateMessage, "\($0), messages: \(_messages)")
        }

        #expect(messages[0].embeds?.first?.title == "Vapor Logger doesn't log any messages into System Log")
        #expect(messages[1].embeds?.first?.title == "Postgre-Kit: Unable to complete code access to PostgreSQL DB")
        #expect(messages[2].embeds?.first?.title == "How to decide to use siblings or parent/children relations in vapor?")
        #expect(messages[3].embeds?.first?.title == "How to make a optional query filter in Vapor")

        let lastCheckDate = await self.context.soChecker.storage.lastCheckDate
        #expect(lastCheckDate != nil)

        serviceTask.cancel()
    }

    @Test
    func swiftReleasesChecker() async throws {
        let serviceTask = Task<Void, any Error> { [self] in
            try await self.context.swiftReleasesChecker.run()
        }

        let endpoint = APIEndpoint.createMessage(channelId: Constants.Channels.release.id)
        let _message = await responseStorage.awaitResponse(at: endpoint).value
        let message = try #require(_message as? Payloads.CreateMessage, "\(_message)")

        #expect(message.embeds?.first?.title == "Swift Release 6.0.1")

        /// No more messages should be sent
        let _newMessage = await responseStorage.awaitResponse(
            at: endpoint,
            expectFailure: true
        ).value
        let newMessage: Never? = try #require(_newMessage as? Optional<Never>)
        #expect(newMessage == .none)

        serviceTask.cancel()
    }

    @Test
    func faqsCommand() async throws {
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .faqsAdd,
                as: Payloads.InteractionResponse.self
            )
            switch response.data {
            case .modal: break
            default:
                Issue.record("Wrong response data type for `/faqs add`: \(response.data as Any)")
            }
        }
        
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .faqsAddFailure,
                as: Payloads.EditWebhookMessage.self
            )
            let message = try #require(response.embeds?.first?.description)
            #expect(message.hasPrefix("You don't have access to this command; it is only available to"), "\(message)")
        }
        
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .faqsGet,
                as: Payloads.EditWebhookMessage.self
            )
            let message = try #require(response.embeds?.first?.description)
            #expect(message == "Test working directory help")
        }
        
        do {
            let key = EventKey.faqsGetEphemeral
            let response = try await manager.sendAndAwaitResponse(
                key: key,
                endpoint: key.responseEndpoints[1],
                as: Payloads.InteractionResponse.self
            )
            if case let .flags(flags) = response.data {
                #expect(
                    flags.flags?.contains(.ephemeral) == true,
                    "\(flags.flags?.representableValues() ?? [])"
                )
            } else {
                Issue.record("Unexpected response: \(response)")
            }
        }
        
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .faqsGetAutocomplete,
                as: Payloads.InteractionResponse.self
            )
            switch response.data {
            case .autocomplete: break
            default:
                Issue.record("Wrong response data type for `/faqs get`: \(response.data as Any)")
            }
        }
    }
    
    @Test
    func autoFaqsCommand() async throws {
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .autoFaqsAdd,
                as: Payloads.InteractionResponse.self
            )
            switch response.data {
            case .modal: break
            default:
                Issue.record("Wrong response data type for `/auto-faqs add`: \(response.data as Any)")
            }
        }
        
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .autoFaqsAddFailure,
                as: Payloads.EditWebhookMessage.self
            )
            let message = try #require(response.embeds?.first?.description)
            #expect(message.hasPrefix("You don't have access to this command; it is only available to"), "\(message)")
        }
        
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .autoFaqsGet,
                as: Payloads.EditWebhookMessage.self
            )
            let message = try #require(response.embeds?.first?.description)
            #expect(message == "Update your PostgresNIO!")
        }
        
        do {
            let key = EventKey.autoFaqsGetEphemeral
            let response = try await manager.sendAndAwaitResponse(
                key: key,
                endpoint: key.responseEndpoints[1],
                as: Payloads.InteractionResponse.self
            )
            if case let .flags(flags) = response.data {
                #expect(
                    flags.flags?.contains(.ephemeral) == true,
                    "\(flags.flags?.representableValues() ?? [])"
                )
            } else {
                Issue.record("Unexpected response: \(response)")
            }
        }
        
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .autoFaqsGetAutocomplete,
                as: Payloads.InteractionResponse.self
            )
            switch response.data {
            case .autocomplete: break
            default:
                Issue.record("Wrong response data type for `/auto-faqs get`: \(response.data as Any)")
            }
        }
        
        do {
            let response = try await manager.sendAndAwaitResponse(
                key: .autoFaqsTrigger,
                as: Payloads.CreateMessage.self
            )
            
            let embed = try #require(response.embeds?.first)
            
            #expect(embed.title == "🤖 Automated Answer")
            #expect(embed.description == "Update your PostgresNIO!")
        }
        
        /// This one should fail since there is a rate-limiter
        do {
            let key: EventKey = .autoFaqsTrigger
            await manager.send(key: key)
            let response = await responseStorage.awaitResponse(
                at: key.responseEndpoints[0],
                expectFailure: true
            ).value
            let payload: Never? = try #require(response as? Optional<Never>, "\(response)")
            #expect(payload == .none)
        }
    }
}
