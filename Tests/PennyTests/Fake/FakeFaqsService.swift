import AsyncHTTPClient
import Models
import Shared

@testable import Penny

struct FakeFaqsService: FaqsService {

    init() {}

    private let all = ["Working Directory": "Test working directory help"]

    func insert(name: String, value: String) async throws {}

    func remove(name: String) async throws {}

    func get(name: String) async throws -> String? {
        self.all[name]
    }

    func getName(hash: Int) async throws -> String? {
        self.all.first(where: { $0.key.stableHash == hash })?.key
    }

    func getAll() async throws -> [String: String] {
        self.all
    }
}
