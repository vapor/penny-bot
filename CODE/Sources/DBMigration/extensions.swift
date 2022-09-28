import Foundation
import PennyModels

extension DynamoDBUser {
    init(migrationUser: MigrationUser) {
        let user = User(
            id: migrationUser.id,
            discordID: migrationUser.discordID,
            githubID: migrationUser.githubID,
            numberOfCoins: migrationUser.numberOfCoins,
            coinEntries: migrationUser.coinEntries,
            createdAt: migrationUser.createdAt
        )
        self.init(user: user)
    }
}
