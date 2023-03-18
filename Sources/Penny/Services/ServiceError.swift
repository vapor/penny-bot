import NIOHTTP1

enum ServiceError: Error {
    case badStatus(HTTPResponseStatus)
}
