import OpenAPIRuntime
import Foundation

public struct FakeClientTransport: ClientTransport {

    public init() { }

    public func send(
        _ request: Request,
        baseURL: URL,
        operationID: String
    ) async throws -> Response {
        guard let data = TestData.for(ghOperationId: operationID) else {
            fatalError("No test data for operation id: \(operationID), baseURL: \(baseURL), request: \(request)")
        }
        let statusCode = request.method == .post ? 201 : 200
        return Response(statusCode: statusCode, body: data)
    }
}
