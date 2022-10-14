@testable import PennyBOT
@testable import DiscordBM
import XCTest

class GatewayManagerTests: XCTestCase {
    
    let manager = MockedManager.shared
    
    override func setUp() async throws {
        Penny.makeBot = { _, _ in MockedManager.shared }
        try await Penny.main()
    }
    
    func testSomething() async throws {
        let response = try await manager.sendAndAwaitResponse(
            key: .thanksMessage,
            endpoint: .postCreateMessage(channelId: "441327731486097429"),
            as: DiscordChannel.CreateMessage.self
        )
        let description = try XCTUnwrap(response.embeds?.first?.description)
//        XCTAssertEqual(description, "")
    }
}
