@testable import Penny
import Models
import AsyncHTTPClient

public struct FakeFaqsService: FaqsService {

    public init() { }

    private let all = ["Working Directory": "Test working directory help"]

    public func initialize(httpClient: HTTPClient) async { }

    public func insert(name: String, value: String) async throws { }

    public func remove(name: String) async throws { }

    public func get(name: String) async throws -> String? {
        self.all[name]
    }

    public func getName(hash: Int) async throws -> String? {
        return nil
    }

    public func getAll() async throws -> [String: String] {
        self.all
    }
}
