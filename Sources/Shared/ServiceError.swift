import NIOHTTP1
import AsyncHTTPClient

enum ServiceError: Error {
    case badStatus(HTTPClientResponse)
}
