//
//  File.swift
//  
//
//  Created by Mahdi Bahrami on 9/13/22.
//

import XCTest
@testable import PennyBOT

class CoinHandlerTests: XCTestCase {
    
    /// Pattern `@mahdi thanks!`
    func testUserAndCoinSignTheWholeMessage() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
            <@21939123912932193> thanks!
            """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thank you!
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
    }
    
    /// Pattern `@mahdi xxxx thanks!`
    func testUserAtTheBeginningAndCoinSignAtTheEnd() throws {
        let coinHandler = CoinHandler(
            text: """
            <@21939123912932193> xxxx xxxx <@4912300012398455> xxxx thank you!
            """
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
                xxxx <@21939123912932193> :coin:
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193> <@4912300012398455> :coin:
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx :coin: <@21939123912932193>
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx :coin: <@21939123912932193> <@4912300012398455>
                """
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
                xxxx <@21939123912932193> thank you! xxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193> <@4912300012398455> thank you! xxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx thank you! <@21939123912932193> xxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx thank you! <@21939123912932193> <@4912300012398455> xxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx ++ <@21939123912932193> <@4912300012398455> xxx
                """
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
                xxxx <@21939123912932193>  thanks xxxx xxxx <@4912300012398455> :thumbsup: xxxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `@mahdi thanks! xxxx @benny thanks! xxxx`
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thanks xxxx <@4912300012398455>  :thumbsup: xxxx xxxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `thanks! @mahdi xxxx thanks! @benny xxxx`
        do {
            let coinHandler = CoinHandler(
                text: """
                thank you!  <@21939123912932193> xxxx :thumbsup:  <@4912300012398455>   xxxx xxxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `xxxx @mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx <@21939123912932193> thanks xxxx xxxx <@4912300012398455>  :thumbsup:
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `@mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193> thanks xxxx <@4912300012398455> :thumbsup: xxxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `@mahdi thanks! @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193>  thanks!  <@4912300012398455> :thumbsup:
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `thanks! @mahdi thanks! @benny`
        do {
            let coinHandler = CoinHandler(
                text: """
                thanks!  <@21939123912932193> ++  <@4912300012398455>
                """
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
                thanks! xxxx xxxx
                """,
                replied: "<@21939123912932193>"
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
                xxxx xxxx :coin:
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
    
    func testExcludedUsers() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thanks!
                """,
                excludedUsers: ["<@21939123912932193>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx <@21939123912932193>  thanks xxxx xxxx <@4912300012398455> :thumbsup:
                """,
                excludedUsers: ["<@21939123912932193>", "<@4912300012398455>"]
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, [])
        }
    }
    
    func testExcludeRoles() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                <@!800138494885124> thanks!
                """
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
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> <@21939123912932193> xxxx ++
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx <@21939123912932193> thanks xxxx <@21939123912932193> :thumbsup: xxxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
    }
    
    func testMultipleLines() throws {
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thank you!
                <@4912300012398455> ++
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> xxxx xxxx thanks!
                xxxx <@4912300012398455> :thumbsup: xxxx
                """
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
    }
    
    func testMaxUserCount() throws {
        let coinedUsers = (0..<50).map { _ in
            "<@\(Int.random(in: 1_000_000_000_000..<1_000_000_000_000_000))> ++"
        }
        do {
            let coinHandler = CoinHandler(text: coinedUsers.joined(separator: "\n"))
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, coinHandler.maxUsers)
        }
        
        do {
            let coinHandler = CoinHandler(text: coinedUsers.joined(separator: " "))
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, coinHandler.maxUsers)
        }
    }
}

private extension CoinHandler {
    init(text: String, replied repliedUser: String? = nil, excludedUsers: [String] = []) {
        self.init(
            text: text,
            repliedUser: repliedUser,
            excludedUsers: excludedUsers
        )
    }
}
