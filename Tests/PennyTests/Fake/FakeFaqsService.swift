@testable import Penny
import Models
import AsyncHTTPClient

package struct FakeFaqsService: FaqsService {

    package init() { }

    private let all = ["Working Directory": "Test working directory help"]

    package func insert(name: String, value: String) async throws { }

    package func remove(name: String) async throws { }

    package func get(name: String) async throws -> String? {
        self.all[name]
    }

    package func getName(hash: Int) async throws -> String? {
        self.all.first(where: { $0.key.hash == hash })?.key
    }

    package func getAll() async throws -> [String: String] {
        self.all
    }
}
