import AsyncHTTPClient
import Models
import NIOHTTP1

enum ServiceError: Error {
    case badStatus(HTTPClientResponse)
    case unexpectedUsersLambdaResponse(UsersLambdaResponse)
}
