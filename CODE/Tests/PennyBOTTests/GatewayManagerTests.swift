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
//        let event = try! JSONDecoder().decode(
//            Gateway.Event.self,
//            from: Data(messageText.utf8)
//        )
        await manager.send(key: .message_1)
    }
}
