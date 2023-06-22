@testable import PennyBOT
import PennyModels
import AsyncHTTPClient

public struct FakeHelpsService: HelpsService {

    public init() { }

    public func initialize(httpClient: HTTPClient) async { }

    public func insert(name: String, value: String) async throws {
        _ = try await FakeHelpsRepository().insert(name: name, value: value)
    }

    public func remove(name: String) async throws {
        _ = try await FakeHelpsRepository().remove(name: name)
    }

    public func get(name: String) async throws -> String? {
        try await self.getAll()[name]
    }

    public func get(nameHash: Int) async throws -> String? {
        fatalError("not implemented")
    }

    public func getAll() async throws -> [String: String] {
        try await FakeHelpsRepository().getAll()
    }
}
