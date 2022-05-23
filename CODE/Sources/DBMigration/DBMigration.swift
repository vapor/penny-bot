//
//  File.swift
//  
//
//  Created by Benny De Bock on 19/04/2022.
//

import Foundation
import PennyModels
import SotoCore
import SotoDynamoDB

@main
struct DBMigration {
    static func main() async throws {
        let configuration = FileLocations()
        var converter = ModelConverter()

        let accountStrings = configuration.returnFileData(from: configuration.URLAccounts)
        let coinStrings = configuration.returnFileData(from: configuration.URLCoins)

        converter.textToAccount(from: accountStrings)
        converter.textToCoin(from: coinStrings)
        converter.oldAccountToNewUser()
        converter.oldCoinsToNewUsers()

        let DBUsers: [DynamoDBUser] = converter.toDynamoDBUsers()

        // TODO: Continue working on migrating data to a local DB
        let awsClient = AWSClient(httpClientProvider: .createNew)
        let euWest = Region(awsRegionName: "eu-west-1")
        let dynamoDB = DynamoDB(
            client: awsClient,
            region: euWest//,
//            endpoint: "http://localhost:8091/"
        )

        let tableName = "penny-bot-table"
        let logger = Logger(label: "migration")
        let eventLoop = awsClient.eventLoopGroup.next()

        for user in DBUsers {
            let input = DynamoDB.PutItemCodableInput(item: user, tableName: tableName)
            
            _ = try await dynamoDB.putItem(input, logger: logger, on: eventLoop)
        }

        try awsClient.syncShutdown()
    }
}


