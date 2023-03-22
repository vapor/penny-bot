@testable import PennyBOT
import XCTest

class CoinHandlerTests: XCTestCase {
    
    let user1 = "<@21939123912932193>"
    let user2 = "<@49123000123984550>"
    
    /// Pattern `@mahdi thanks!`
    func testUserAndCoinSignTheWholeMessage() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1) thanks!
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1) thank you!
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
    }
    
    /// Pattern `@mahdi xxxx thanks!`
    func testUserAtTheBeginningAndCoinSignAtTheEnd() throws {
        let coinHandler = CoinHandler(
            text: """
            \(user1) xxxx xxxx \(user2) xxxx thank you so MUCH!
            """,
            mentionedUsers: [user1, user2]
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, [user1])
    }
    
    /// Pattern `thank you xxxx @mahdi!`
    func testUserAtTheEndAndCoinSignAtTheBeginning() throws {
        let coinHandler = CoinHandler(
            text: """
            thaNk you xxxx xxxx \(user2) xxxx xxxx \(user1)!
            """,
            mentionedUsers: [user2, user1]
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, [user1])
    }
    
    /// Patterns `xxxx @mahdi thanks!`
    /// `xxxx thanks! @mahdi`
    func testUserAndCoinSignAtTheEnd() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx \(user1) 🪙
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx \(user1) \(user2) 🚀
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx ++++++++++++++++++++++++++++++ \(user1)
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx Thanks for your help \(user1) \(user2)
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
    }
    
    /// Patterns `xxxx @mahdi thanks! xxxx`
    /// `xxxx thanks! @mahdi xxxx`
    func testUserAndCoinSignInTheMiddle() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx \(user1) thanks a bunch! xxx
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx \(user1) \(user2) thank you A bunch! xxx
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx thank you. \(user1) xxx
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx thank you!\(user1)  \(user2)   xxx
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx thanks for the help\(user1)  \(user2) xxx
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
    }
    
    func testNotReallyACoinSign() throws {
        do {
            /// `+` is not a coin sign, unlike `++`/`+++`/`++++`... .
            let coinHandler = CoinHandler(
                text: """
                \(user1) +
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
        
        do {
            /// `++` is too far.
            let coinHandler = CoinHandler(
                text: """
                \(user1) xxxx ++ xxxx
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
    }
    
    /// Patterns `xxxx @mahdi thanks! xxxx @benny thanks! xxxx`
    /// `@mahdi thanks! xxxx @benny thanks! xxxx`
    /// `thanks! @mahdi xxxx thanks! @benny xxxx`
    /// `xxxx @mahdi thanks! xxxx @benny thanks!`
    /// `@mahdi thanks! xxxx @benny thanks!`
    /// `@mahdi thanks! @benny thanks!`
    /// `thanks! @mahdi thanks! @benny`
    func testMultipleUsersWithCoinSign() throws {
        /// `xxxx @mahdi thanks! xxxx @benny thanks! xxxx`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx \(user1)  thanks for the xxxx xxxx xxxx, xxxx xxxx \(user2) \(Constants.vaporCoinEmoji) xxxx
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        /// `@mahdi thanks! xxxx @benny thanks! xxxx`
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1) thanks xxxx \(user2) & 🙌🏽 xxxx xxxx
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        /// `thanks! @mahdi xxxx thanks! @benny xxxx`
        do {
            let coinHandler = CoinHandler(
                text: """
                thanks a bunch!  \(user1) xxxx thanks a LOT  \(user2)   xxxx xxxx
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        /// `xxxx @mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx \(user1) thanks xxxx xxxx \(user2)  thanks for the help!
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        /// `@mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx \(user1)thanks xxxx \(user2) += 1 xxxx
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        /// `@mahdi thanks! @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1)THANK YOU!  \(user2) and 👍🏼
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        /// `thanks! @mahdi thanks! @benny`
        do {
            let coinHandler = CoinHandler(
                text: """
                thanks!  \(user1) ++ , \(user2)
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
    }
    
    func testRepliedUser() throws {
        /// thanks!
        do {
            let coinHandler = CoinHandler(
                text: """
                thanks!
                """,
                replied: user1
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        /// thanks! @tim xxxx xxxx
        do {
            let coinHandler = CoinHandler(
                text: """
                Thanks \(user1) xxxx xxxx
                """,
                replied: user1,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        /// xxxx xxxx thanks!
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx ++
                """,
                replied: user1
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        /// xxxx xxxx \n xxxx xxxx thanks!
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx
                xxxx xxxx 🪙
                """,
                replied: user1
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        /// thanks!
        /// But replied user is in excluded users.
        do {
            let coinHandler = CoinHandler(
                text: """
                thanks!
                """,
                replied: user1,
                excludedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
    }
    
    /// User-id strings that are not in `mentionedUsers` won't get any coins,
    /// because Discord has not verified the mention.
    func testMentionedUsers() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1) thanks!
                """,
                mentionedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx \(user1)  thanks xxxx xxxx \(user2) 🙌🏼
                """,
                mentionedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
    }
    
    func testExcludedUsers() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1) thANKs!
                """,
                excludedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx \(user1)  thanks xxxx xxxx \(user2) 👍🏼
                """,
                excludedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
    }
    
    func testUniqueUsers() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1) thank you! \(user1) +++
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1) \(user1) xxxx +++++
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx \(user1) thanks xxxx \(user1) 👌🏻 xxxx
                """,
                mentionedUsers: [user1]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1])
        }
    }
    
    func testMultipleLines() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1) ThAnK yOu!
                \(user2) ++
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                \(user1) xxxx xxxx thanks!
                xxxx \(user2) thanks xxxx
                """,
                mentionedUsers: [user1, user2]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1, user2])
        }
    }
    
    func testMaxUserCount() throws {
        let count = 55
        let coinedUsers = (0..<count).map { _ in
            "<@\(Int.random(in: 1_000_000_000_000..<1_000_000_000_000_000))>"
        }
        let coinStrings = coinedUsers.map { "\($0) ++" }
        do {
            let coinHandler = CoinHandler(
                text: coinStrings.joined(separator: "\n"),
                mentionedUsers: coinedUsers
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, CoinHandler.maxUsers)
        }
        
        do {
            let coinHandler = CoinHandler(
                text: coinStrings.joined(separator: " "),
                mentionedUsers: coinedUsers
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, CoinHandler.maxUsers)
        }
        
        do {
            let part1 = coinStrings[0..<5]
            let part2 = coinStrings[5..<count]
            let coinHandler = CoinHandler(
                text: part1.joined(separator: " ") + "\n" + part2.joined(separator: "\n"),
                mentionedUsers: coinedUsers
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, CoinHandler.maxUsers)
        }
        
        do {
            let part1 = coinStrings[0..<15]
            let part2 = coinStrings[15..<count]
            let coinHandler = CoinHandler(
                text: part1.joined(separator: " ") + "\n" + part2.joined(separator: "\n"),
                mentionedUsers: coinedUsers
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, CoinHandler.maxUsers)
        }
    }
}

private extension CoinHandler {
    init(
        text: String,
        replied repliedUser: String? = nil,
        mentionedUsers: [String] = [],
        excludedUsers: [String] = []
    ) {
        self.init(
            text: text,
            repliedUser: repliedUser,
            mentionedUsers: mentionedUsers,
            excludedUsers: excludedUsers
        )
    }
}
