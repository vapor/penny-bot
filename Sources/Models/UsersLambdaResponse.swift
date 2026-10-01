package import NewCodable

@JSONCodable
package enum UsersLambdaResponse: Sendable {
    case coinAdded(CoinResponse)
    case user(DynamoDBUser)
    case userIfFound(DynamoDBUser?)
    case done
}
