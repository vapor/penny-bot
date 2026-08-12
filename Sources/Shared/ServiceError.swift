import Models

enum ServiceError: Error {
    case unexpectedUsersLambdaResponse(UsersLambdaResponse)
}
