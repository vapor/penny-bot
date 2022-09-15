//
//  File.swift
//  
//
//  Created by Mahdi Bahrami on 9/13/22.
//

import XCTest
@testable import PennyBOT

class CoinHandlerTests: XCTestCase {
    
    /// Pattern `@mahdi xxxx thanks!`
    func testUserAndCoinSuffixTheWholeMessage() throws {
        let coinHandler = CoinHandler(
            text: """
            <@21939123912932193> thanks!
            """,
            excludedUsers: []
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, ["<@21939123912932193>"])
    }
    
    /// Pattern `@mahdi xxxx thanks!`
    func testUserAtTheBeginningAndCoinSuffixAtTheEnd() throws {
        let coinHandler = CoinHandler(
            text: """
            <@21939123912932193> xxxx xxxx <@4912300012398455> xxxx thank you!
            """,
            excludedUsers: []
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, ["<@21939123912932193>"])
    }
    
    /// Pattern `xxxx @mahdi thanks!`
    func testUserAndCoinSuffixAtTheEnd() throws {
        let coinHandler = CoinHandler(
            text: """
            xxxx <@21939123912932193> :coin:
            """,
            excludedUsers: []
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, ["<@21939123912932193>"])
    }
    
    /// Pattern `xxxx @mahdi thanks! xxxx`
    func testUserAndCoinSuffixInTheMiddle() throws {
        let coinHandler = CoinHandler(
            text: """
            xxxx <@21939123912932193> thank you! xxx
            """,
            excludedUsers: []
        )
        let users = coinHandler.findUsers()
        XCTAssertEqual(users, ["<@21939123912932193>"])
    }
    
    /// Patterns `xxxx @mahdi thanks! xxxx @benny thanks! xxxx`
    /// `@mahdi thanks! xxxx @benny thanks! xxxx`
    /// `xxxx @mahdi thanks! xxxx @benny thanks!`
    /// `@mahdi thanks! xxxx @benny thanks!`
    /// `@mahdi thanks! @benny thanks!`
    func testMultipleUsersWithCoinSuffix() throws {
        /// `xxxx @mahdi thanks! xxxx @benny thanks! xxxx`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193> thanks xxxx xxxx <@4912300012398455> :thumbsup: xxxx
                """,
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `@mahdi thanks! xxxx @benny thanks! xxxx`
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thanks xxxx <@4912300012398455> :thumbsup: xxxx xxxx
                """,
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `xxxx @mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx <@21939123912932193> thanks xxxx xxxx <@4912300012398455> :thumbsup:
                """,
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `@mahdi thanks! xxxx @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx <@21939123912932193> thanks xxxx <@4912300012398455> :thumbsup: xxxx
                """,
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        /// `@mahdi thanks! @benny thanks!`
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> thanks! <@4912300012398455> :thumbsup:
                """,
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
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
                xxxx xxxx <@21939123912932193> thanks xxxx xxxx <@4912300012398455> :thumbsup:
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
                """,
                excludedUsers: []
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
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> <@21939123912932193> xxxx ++
                """,
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                xxxx xxxx <@21939123912932193> thanks xxxx <@21939123912932193> :thumbsup: xxxx
                """,
                excludedUsers: []
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
                """,
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users, ["<@21939123912932193>", "<@4912300012398455>"])
        }
        
        do {
            let coinHandler = CoinHandler(
                text: """
                <@21939123912932193> xxxx xxxx thanks!
                xxxx <@4912300012398455> :thumbsup: xxxx
                """,
                excludedUsers: []
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
            let coinHandler = CoinHandler(
                text: coinedUsers.joined(separator: "\n"),
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, coinHandler.maxUsers)
        }
        
        do {
            let coinHandler = CoinHandler(
                text: coinedUsers.joined(separator: " "),
                excludedUsers: []
            )
            let users = coinHandler.findUsers()
            XCTAssertEqual(users.count, coinHandler.maxUsers)
        }
    }
}
