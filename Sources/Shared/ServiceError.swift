import AsyncHTTPClient
import NIOHTTP1

enum ServiceError: Error {
    case badStatus(HTTPClientResponse)
}
