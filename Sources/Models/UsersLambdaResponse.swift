package enum UsersLambdaResponse: Sendable, Codable {
    case coinAdded(CoinResponse)
    case user(DynamoDBUser)
    case userIfFound(DynamoDBUser?)
    case done
}
