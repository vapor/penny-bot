import Foundation
import OpenAPIRuntime

public struct FakeClientTransport: ClientTransport {

    public init() {}

    public func send(
        _ request: Request,
        baseURL: URL,
        operationID: String
    ) async throws -> Response {
        let primaryID = "\(request.method.name)-\(baseURL.absoluteString)\(request.path)"
        guard
            let data = TestData.for(ghRequestID: primaryID)
                ?? TestData.for(ghRequestID: operationID)
        else {
            fatalError(
                "No test GitHub data for primary id: \(primaryID), operation id: \(operationID)."
            )
        }
        let statusCode = request.method == .post ? 201 : 200
        return Response(statusCode: statusCode, body: data)
    }
}
