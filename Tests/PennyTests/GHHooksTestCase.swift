@testable import GHHooksLambda
import AsyncHTTPClient
import GitHubAPI
import Fake
import Logging
import XCTest

protocol GHHooksTestCase: XCTestCase {
    var ghHooksDecoder: JSONDecoder { get }
    var httpClient: HTTPClient { get }
}

private let sharedDecoder: JSONDecoder = {
    var decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()


extension GHHooksTestCase {
    var ghHooksDecoder: JSONDecoder {
        sharedDecoder
    }
    
    func makeContext(eventName: GHEvent.Kind, eventKey: String) throws -> HandlerContext {
        let data = TestData.for(ghEventKey: eventKey)!
        let event = try sharedDecoder.decode(GHEvent.self, from: data)
        return try makeContext(
            eventName: eventName,
            event: event
        )
    }

    func makeContext(eventName: GHEvent.Kind, event: GHEvent) throws -> HandlerContext {
        let logger = Logger(label: "GHHooksTests")
        return HandlerContext(
            eventName: eventName,
            event: event,
            httpClient: httpClient,
            discordClient: FakeDiscordClient(),
            githubClient: Client(
                serverURL: try Servers.server1(),
                transport: FakeClientTransport()
            ),
            renderClient: RenderClient(
                renderer: try .forGHHooks(
                    httpClient: httpClient,
                    logger: logger
                )
            ),
            messageLookupRepo: FakeMessageLookupRepo(),
            logger: logger
        )
    }
}
