//
//  File.swift
//  
//
//  Created by Benny De Bock on 19/04/2022.
//

import Foundation
import PennyModels

struct ModelConverter {
    // MARK: - Convert old object to new database objects
    //New format
    var userAccounts: [MigrationUser] = []
    
    func toDynamoDBUsers() -> [DynamoDBUser] {
        var dynamoUsers: [DynamoDBUser] = []
        
        userAccounts.forEach { account in
            dynamoUsers.append(DynamoDBUser(migrationUser: account))
        }
        
        return dynamoUsers
    }
    
    mutating func oldCoinsToNewUsers() {
        coins.forEach { coin in
            var entryReason: CoinEntryReason
            var entrySource: CoinEntrySource
            var fromUser: MigrationUser
            var indexToUser: Int
            
            //checkIfUserExists
            if let userExists = userAccounts.first(where: { $0.discordID!.contains(coin.from) || $0.githubID!.contains(coin.from) || $0.slackID!.contains(coin.from) }){
                fromUser = userExists
            } else {
                let newUser = MigrationUser(
                    id: UUID(),
                    discordID: "<@\(coin.from)>",
                    githubID: coin.from,
                    slackID: coin.from,
                    numberOfCoins: 0,
                    coinEntries: [],
                    createdAt: Date())
                userAccounts.append(newUser)
            }

            switch coin.source {
            case "discord":
                entrySource = .discord
                fromUser = userAccounts.first(where: { $0.discordID!.contains(coin.from)})!
                indexToUser = userAccounts.firstIndex(where: { $0.discordID!.contains(coin.to)})!
            case "github":
                entrySource = .github
                fromUser = userAccounts[0]
                indexToUser = userAccounts.firstIndex(where: { $0.githubID!.contains(coin.to)}) ?? -1
            case "slack":
                entrySource = .penny
                fromUser = userAccounts[0]
                indexToUser = userAccounts.firstIndex(where: { $0.slackID!.contains(coin.to)}) ?? -1
            default:
                entrySource = .penny
                fromUser = userAccounts[0]
                indexToUser = userAccounts.firstIndex(where: { $0.githubID!.contains(coin.to) || $0.discordID!.contains(coin.to) }) ?? -1
            }
            
            if indexToUser == -1 {
                let newUser = MigrationUser(
                    id: UUID(),
                    discordID: "<@\(coin.to)>",
                    githubID: coin.to,
                    slackID: coin.to,
                    numberOfCoins: 0,
                    coinEntries: [],
                    createdAt: Date())
                userAccounts.append(newUser)
                
                indexToUser = userAccounts.firstIndex(where: { $0.githubID!.contains(coin.to)})!
            }
            
            switch coin.reason {
            case "twas but a gift":
                entryReason = .userProvided
            case let str where str.contains("merged"):
                entryReason = .prSubmittedAndClosed
            case let str where str.contains("linked"):
                entryReason = .linkedProfile
            default:
                entryReason = .transferred
            }
            
            let coinEntry = CoinEntry(
                id: coin.id,
                createdAt: coin.createdAt,
                amount: coin.value,
                from: fromUser.id,
                source: entrySource,
                reason: entryReason
            )
            
            userAccounts[indexToUser].addCoinEntry(coinEntry)
        }
    }
    
    mutating func oldAccountToNewUser() {
        let penny = MigrationUser(
            id: UUID(uuidString: "E9A6D75F-1EC4-4979-BFEB-646CAF1BB162")!,
            discordID: "<@950695294906007573>",
            githubID: "950695294906007573",
            slackID: "950695294906007573",
            numberOfCoins: 0,
            coinEntries: [],
            createdAt: Date()
        )
        userAccounts.append(penny)
        
        accounts.forEach { account in
            let user = MigrationUser(
                id: account.id,
                discordID: "<@\(account.discord)>",
                githubID: account.github,
                slackID: account.slack,
                numberOfCoins: 0,
                coinEntries: [],
                createdAt: Date()
            )
            userAccounts.append(user)
        }
    }
    
    // MARK: - Convert text to objects
    //Old format
    var accounts: [Account] = []
    var coins: [Coin] = []
    
    mutating func textToAccount(from lines: [String]) {
        lines.forEach { line in
            let values = line.components(separatedBy: "\t")
            let account = Account(
                id: UUID(uuidString: values[0])!,
                slack: values[1],
                github: values[2],
                discord: values[3])
            accounts.append(account)
        }
    }
    
    mutating func textToCoin(from lines: [String]) {
        lines.forEach { line in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSS"
            
            let values = line.components(separatedBy: "\t")
            let seconds = dateFormatter.date(from: values[6])!.timeIntervalSince1970
            
            let coin = Coin(
                id: UUID(uuidString: values[0])!,
                source: values[1],
                to: values[2],
                from: values[3],
                reason: values[4],
                value: Int(values[5])!,
                createdAt: Date(timeIntervalSince1970: seconds)
            )
            
            coins.append(coin)
        }
    }
}
