import OpenAPIRuntime
import Foundation

public struct FakeClientTransport: ClientTransport {

    public init() { }

    public func send(
        _ request: Request,
        baseURL: URL,
        operationID: String
    ) async throws -> Response {
        Response(statusCode: 200)
    }
}
