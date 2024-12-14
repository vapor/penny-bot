import HTTPTypes
import OpenAPIRuntime

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct FakeClientTransport: ClientTransport {

    init() {}

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let primaryID = "\(request.method.rawValue)-\(baseURL.absoluteString)\(request.path ?? "")"
        guard let data = TestData.for(ghRequestID: primaryID) ?? TestData.for(ghRequestID: operationID) else {
            fatalError("No test GitHub data for primary id: \(primaryID), operation id: \(operationID).")
        }
        let body = HTTPBody(data)
        let response = HTTPResponse(status: request.method == .post ? .created : .ok)
        return (response, body)
    }
}
