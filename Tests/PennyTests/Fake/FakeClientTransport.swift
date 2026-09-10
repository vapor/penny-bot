import HTTPTypes
import OpenAPIRuntime

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct FakeClientTransport: ClientTransport {

    /// Operations that don't respond with the `POST`/non-`POST` default.
    private static let knownStatuses: [String: HTTPResponse.Status] = [
        "actions/create-workflow-dispatch": .noContent
    ]

    /// Keyed by operation id, for tests that need to see a failure response.
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
        let primaryID = "\(request.method.rawValue)-\(baseURL.absoluteString)\(request.path ?? "")"

        await self.recorder.record(
            .init(
                operationID: operationID,
                method: request.method,
                path: request.path ?? "",
                body: body
            )
        )

        guard let data = TestData.for(ghRequestID: primaryID) ?? TestData.for(ghRequestID: operationID) else {
            fatalError("No test GitHub data for primary id: \(primaryID), operation id: \(operationID).")
        }
        let status =
            self.statusOverrides[operationID]
            ?? Self.knownStatuses[operationID]
            ?? (request.method == .post ? .created : .ok)
        return (HTTPResponse(status: status), HTTPBody(data))
    }
}
