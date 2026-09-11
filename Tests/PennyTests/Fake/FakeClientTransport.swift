import HTTPTypes
import OpenAPIRuntime

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct FakeClientTransport: ClientTransport {

    /// Keyed by operation id, for tests that need to see a failure response.
    /// The response is then looked up with the status code appended to the request id.
    let statusOverrides: [String: HTTPResponse.Status]
    let recorder: GitHubRequestsRecorder

    init(statusOverrides: [String: HTTPResponse.Status] = [:]) {
        self.statusOverrides = statusOverrides
        self.recorder = GitHubRequestsRecorder()
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        await self.recorder.record(
            .init(
                operationID: operationID,
                method: request.method,
                path: request.path ?? "",
                body: body
            )
        )

        let suffix = self.statusOverrides[operationID].map { "-\($0.code)" } ?? ""
        let primaryID = "\(request.method.rawValue)-\(baseURL.absoluteString)\(request.path ?? "")\(suffix)"
        let operationID = operationID + suffix
        guard let response = TestData.for(ghRequestID: primaryID) ?? TestData.for(ghRequestID: operationID) else {
            fatalError("No test GitHub data for primary id: \(primaryID), operation id: \(operationID).")
        }
        let headers: HTTPFields = response.body == nil ? [:] : [.contentType: "application/json"]
        let httpResponse = HTTPResponse(status: response.status, headerFields: headers)
        let httpBody = response.body.map { HTTPBody($0) }
        return (httpResponse, httpBody)
    }
}
