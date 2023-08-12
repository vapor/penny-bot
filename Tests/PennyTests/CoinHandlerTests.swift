import DiscordBM
import XCTest

@testable import Penny

class CoinHandlerTests: XCTestCase {

    let user1 = "<@21939123912932193>"
    let user2 = "<@49123000123984550>"

    let user1Snowflake: UserSnowflake = "21939123912932193"
    let user2Snowflake: UserSnowflake = "49123000123984550"

    /// Pattern `@mahdi thanks!`
    func testUserAndCoinSignTheWholeMessage() throws {
        do {
            let coinHandler = CoinFinder(
                text: """
                    \(user1) thanks!
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    \(user1) thank you!
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }
    }

    /// Pattern `@mahdi xxxx thanks!`
    func testUserAtTheBeginningAndCoinSignAtTheEnd() throws {
        let coinHandler = CoinFinder(
            text: """
                \(user1) xxxx xxxx \(user2) xxxx thank you so MUCH!
                """,
            mentionedUsers: [user1Snowflake, user2Snowflake]
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, [user1Snowflake])
    }

    /// Pattern `thank you xxxx @mahdi!`
    func testUserAtTheEndAndCoinSignAtTheBeginning() throws {
        let coinHandler = CoinFinder(
            text: """
                thaNk you xxxx xxxx \(user2) xxxx xxxx \(user1)!
                """,
            mentionedUsers: [user2Snowflake, user1Snowflake]
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, [user1Snowflake])
    }

    /// Patterns `xxxx @mahdi thanks!`
    /// `xxxx thanks! @mahdi`
    func testUserAndCoinSignAtTheEnd() throws {
        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx \(user1) 🪙
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx \(user1) \(user2) 🚀
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx ++++++++++++++++++++++++++++++ \(user1)
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx Thanks for your help \(user1) \(user2)
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }
    }

    /// Patterns `xxxx @mahdi thanks! xxxx`
    /// `xxxx thanks! @mahdi xxxx`
    func testUserAndCoinSignInTheMiddle() throws {
        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx \(user1) thanks a bunch! xxx
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx \(user1) \(user2) thank you A bunch! xxx
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx thank you. \(user1) xxx
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx thank you!\(user1)  \(user2)   xxx
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx thanks for the help\(user1)  \(user2) xxx
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }
    }

    func testNotReallyACoinSign() throws {
        do {
            /// `+` is not a coin sign, unlike `++`/`+++`/`++++`... .
            let coinHandler = CoinFinder(
                text: """
                    \(user1) +
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }

        do {
            /// `++` is too far.
            let coinHandler = CoinFinder(
                text: """
                    \(user1) xxxx ++ xxxx
                    """,
                mentionedUsers: [user1Snowflake]
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
            let coinHandler = CoinFinder(
                text: """
                    xxxx \(user1)  thanks for the xxxx xxxx xxxx, xxxx xxxx \(user2) \(Constants.ServerEmojis.coin.emoji) xxxx
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        /// `@mahdi thanks! xxxx @benny thanks! xxxx`
        do {
            let coinHandler = CoinFinder(
                text: """
                    \(user1) thanks xxxx \(user2) & 🙌🏽 xxxx xxxx
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        /// `thanks! @mahdi xxxx thanks! @benny xxxx`
        do {
            let coinHandler = CoinFinder(
                text: """
                    thanks a bunch!  \(user1) xxxx thanks a LOT  \(user2)   xxxx xxxx
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        /// `xxxx @mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx xxxx \(user1) thanks xxxx xxxx \(user2)  thanks for the help!
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        /// `@mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx \(user1)thanks xxxx \(user2) += 1 xxxx
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        /// `@mahdi thanks! @benny thanks!`
        do {
            let coinHandler = CoinFinder(
                text: """
                    \(user1)THANK YOU!  \(user2) and 👍🏼
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        /// `thanks! @mahdi thanks! @benny`
        do {
            let coinHandler = CoinFinder(
                text: """
                    thanks!  \(user1) ++ , \(user2)
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }
    }

    func testRepliedUser() throws {
        /// thanks!
        do {
            let coinHandler = CoinFinder(
                text: """
                    thanks!
                    """,
                replied: user1Snowflake
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        /// thanks! @tim xxxx xxxx
        do {
            let coinHandler = CoinFinder(
                text: """
                    Thanks \(user1) xxxx xxxx
                    """,
                replied: user1Snowflake,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        /// xxxx xxxx thanks!
        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx xxxx ++
                    """,
                replied: user1Snowflake
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        /// xxxx xxxx \n xxxx xxxx thanks!
        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx xxxx
                    xxxx xxxx 🪙
                    """,
                replied: user1Snowflake
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        /// thanks!
        /// But replied user is in excluded users.
        do {
            let coinHandler = CoinFinder(
                text: """
                    thanks!
                    """,
                replied: user1Snowflake,
                excludedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
    }

    /// User-id strings that are not in `mentionedUsers` won't get any coins,
    /// because Discord has not verified the mention.
    func testMentionedUsers() throws {
        do {
            let coinHandler = CoinFinder(
                text: """
                    \(user1) thanks!
                    """,
                mentionedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }

        do {
            let coinHandler = CoinFinder(
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
            let coinHandler = CoinFinder(
                text: """
                    \(user1) thANKs!
                    """,
                excludedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx xxxx \(user1)  thanks xxxx xxxx \(user2) 👍🏼
                    """,
                excludedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
    }

    func testUniqueUsers() throws {
        do {
            let coinHandler = CoinFinder(
                text: """
                    \(user1) thank you! \(user1) +++
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    \(user1) \(user1) xxxx +++++
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    xxxx xxxx \(user1) thanks xxxx \(user1) 👌🏻 xxxx
                    """,
                mentionedUsers: [user1Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake])
        }
    }

    func testMultipleLines() throws {
        do {
            let coinHandler = CoinFinder(
                text: """
                    \(user1) ThAnK yOu!
                    \(user2) ++
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }

        do {
            let coinHandler = CoinFinder(
                text: """
                    \(user1) xxxx xxxx thanks!
                    xxxx \(user2) thanks xxxx
                    """,
                mentionedUsers: [user1Snowflake, user2Snowflake]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [user1Snowflake, user2Snowflake])
        }
    }

    func testMaxUserCount() throws {
        let count = 55
        let coinedUsers = try (0..<count).map { _ in
            try UserSnowflake.makeFake(
                date: Date(timeIntervalSince1970: .random(in: 1_420_070_400...4_398_046_511))
            )
        }
        let coinStrings = coinedUsers.map { "\(DiscordUtils.mention(id: $0)) ++" }
        do {
            let coinHandler = CoinFinder(
                text: coinStrings.joined(separator: "\n"),
                mentionedUsers: coinedUsers
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, CoinFinder.Configuration.maxUsers)
        }

        do {
            let coinHandler = CoinFinder(
                text: coinStrings.joined(separator: " "),
                mentionedUsers: coinedUsers
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, CoinFinder.Configuration.maxUsers)
        }

        do {
            let part1 = coinStrings[0..<5]
            let part2 = coinStrings[5..<count]
            let coinHandler = CoinFinder(
                text: part1.joined(separator: " ") + "\n" + part2.joined(separator: "\n"),
                mentionedUsers: coinedUsers
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, CoinFinder.Configuration.maxUsers)
        }

        do {
            let part1 = coinStrings[0..<15]
            let part2 = coinStrings[15..<count]
            let coinHandler = CoinFinder(
                text: part1.joined(separator: " ") + "\n" + part2.joined(separator: "\n"),
                mentionedUsers: coinedUsers
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, CoinFinder.Configuration.maxUsers)
        }
    }
}

private extension CoinFinder {
    init(
        text: String,
        replied repliedUser: UserSnowflake? = nil,
        mentionedUsers: [UserSnowflake] = [],
        excludedUsers: [UserSnowflake] = []
    ) {
        self.init(
            text: text,
            repliedUser: repliedUser,
            mentionedUsers: mentionedUsers,
            excludedUsers: excludedUsers
        )
    }
}
