import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Records the GitHub requests a handler makes, so tests can assert on them.
actor GitHubRequestsRecorder {
    static let maxBodyBytes = 1 << 20

    struct Request: Sendable {
        let operationID: String
        let method: HTTPRequest.Method
        let path: String
        let body: HTTPBody?
    }

    private(set) var requests: [Request] = []
    let decoder = JSONDecoder()

    init() {}

    func record(_ request: Request) {
        self.requests.append(request)
    }

    func requests(for operationID: String) -> [Request] {
        self.requests.filter { $0.operationID == operationID }
    }

    func paths(for operationID: String) -> [String] {
        self.requests(for: operationID).map(\.path)
    }

    func contains(operationID: String) -> Bool {
        self.requests.contains { $0.operationID == operationID }
    }

    func decodeFirst<Body: Decodable & Sendable>(
        for operationID: String,
        as type: Body.Type = Body.self
    ) async throws -> Body? {
        guard let body = self.requests(for: operationID).first?.body else { return nil }
        let data = try await Data(collecting: body, upTo: Self.maxBodyBytes)
        return try self.decoder.decode(Body.self, from: data)
    }

    func decodeAll<Body: Decodable & Sendable>(
        for operationID: String,
        as type: Body.Type = Body.self
    ) async throws -> [Body] {
        var decoded: [Body] = []
        let requests = self.requests(for: operationID)
        decoded.reserveCapacity(requests.count)
        for request in requests {
            guard let body = request.body else { continue }
            let data = try await Data(collecting: body, upTo: Self.maxBodyBytes)
            let decodedBody = try self.decoder.decode(Body.self, from: data)
            decoded.append(decodedBody)
        }
        return decoded
    }
}
