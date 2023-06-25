@testable import Penny
import Models
import AsyncHTTPClient

public struct FakeFaqsService: FaqsService {

    public init() { }

    public func initialize(httpClient: HTTPClient) async { }

    public func insert(name: String, value: String) async throws {
        _ = try await FakeFaqsRepository().insert(name: name, value: value)
    }

    public func remove(name: String) async throws {
        _ = try await FakeFaqsRepository().remove(name: name)
    }

    public func get(name: String) async throws -> String? {
        try await self.getAll()[name]
    }

    public func getName(hash: Int) async throws -> String? {
        fatalError("not implemented")
    }

    public func getAll() async throws -> [String: String] {
        try await FakeFaqsRepository().getAll()
    }
}
