@testable import PennyBOT
import XCTest

class CoinHandlerTests: XCTestCase {
    
    /// Pattern `@mahdi thanks!`
    func testUserAndCoinSignTheWholeMessage() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thanks!
                """,
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thank you!
                """,
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
    }
    
    /// Pattern `@mahdi xxxx thanks!`
    func testUserAtTheBeginningAndCoinSignAtTheEnd() throws {
        let coinHandler = CoinHandler(
            text: """
            <@21939123912932193> xxxx xxxx <@4912300012398455> xxxx thank you so much!
            """,
            mentionedUsers: ["<@21939123912932193>"]
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, ["<@21939123912932193>"])
    }
    
    /// Pattern `thank you xxxx @mahdi!`
    func testUserAtTheEndAndCoinSignAtTheBeginning() throws {
        let coinHandler = CoinHandler(
            text: """
            thank you xxxx xxxx <@4912300012398455> xxxx xxxx <@21939123912932193>!
            """,
            mentionedUsers: ["<@21939123912932193>"]
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, ["<@21939123912932193>"])
    }
    
    /// Patterns `xxxx @mahdi thanks!`
    /// `xxxx thanks! @mahdi`
    func testUserAndCoinSignAtTheEnd() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193> 🪙
                """,
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193> <@4912300012398455> 🚀
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx ++ <@21939123912932193>
                """,
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx advance(by: 1) <@21939123912932193> <@4912300012398455>
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
    }
    
    /// Patterns `xxxx @mahdi thanks! xxxx`
    /// `xxxx thanks! @mahdi xxxx`
    func testUserAndCoinSignInTheMiddle() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193> thanks a bunch! xxx
                """,
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193> <@4912300012398455> thank you a bunch! xxx
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx thank you! <@21939123912932193> xxx
                """,
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx thank you!<@21939123912932193>  <@4912300012398455>   xxx
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx ++<@21939123912932193>  <@4912300012398455> xxx
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
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
                xxxx <@21939123912932193>  thanks, xxxx xxxx <@4912300012398455> <:coin:473588485962596352> xxxx
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `@mahdi thanks! xxxx @benny thanks! xxxx`
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thanks xxxx <@4912300012398455> & 🙌🏽 xxxx xxxx
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `thanks! @mahdi xxxx thanks! @benny xxxx`
        do {
            let coinHandler = CoinHandler(
                text: """
                thanks a bunch!  <@21939123912932193> xxxx thanks a lot  <@4912300012398455>   xxxx xxxx
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `xxxx @mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx <@21939123912932193> thanks xxxx xxxx <@4912300012398455>  successor()
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `@mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193>thanks xxxx <@4912300012398455> += 1 xxxx
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `@mahdi thanks! @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193>THANK YOU!  <@4912300012398455> and 👍🏼
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `thanks! @mahdi thanks! @benny`
        do {
            let coinHandler = CoinHandler(
                text: """
                thanks!  <@21939123912932193> ++ , <@4912300012398455>
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
    }
    
    func testRepliedUser() throws {
        /// thanks!
        do {
            let coinHandler = CoinHandler(
                text: """
                thanks!
                """,
                replied: "<@21939123912932193>"
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        /// thanks! xxxx xxxx
        do {
            let coinHandler = CoinHandler(
                text: """
                Thanks <@21939123912932193> for your help
                """,
                replied: "<@21939123912932193>",
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        /// xxxx xxxx thanks!
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx ++
                """,
                replied: "<@21939123912932193>"
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        /// xxxx xxxx \n xxxx xxxx thanks!
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx
                xxxx xxxx 🪙
                """,
                replied: "<@21939123912932193>"
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        /// thanks!
        /// But replied user is in excluded users.
        do {
            let coinHandler = CoinHandler(
                text: """
                thanks!
                """,
                replied: "<@21939123912932193>",
                excludedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
    }
    
    /// User-id strings that are not in `mentionedUsers` won't get any coins,
    /// because the mentions are not verified by Discord.
    func testMentionedUsers() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thanks!
                """,
                mentionedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx <@21939123912932193>  thanks xxxx xxxx <@4912300012398455> 🙌🏼
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
                <@21939123912932193> thANKs!
                """,
                excludedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx <@21939123912932193>  thanks xxxx xxxx <@4912300012398455> 👍🏼
                """,
                excludedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
    }
    
    func testUniqueUsers() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thank you! <@21939123912932193> ++
                """,
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> <@21939123912932193> xxxx ++
                """,
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx <@21939123912932193> thanks xxxx <@21939123912932193> 👌🏻 xxxx
                """,
                mentionedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
    }
    
    func testMultipleLines() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> ThAnK yOu!
                <@4912300012398455> ++
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> xxxx xxxx thanks!
                xxxx <@4912300012398455> thanks xxxx
                """,
                mentionedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
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
