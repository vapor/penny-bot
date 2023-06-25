import Foundation
import PennyModels
import PennyRepositories

public struct FakeFaqsRepository: FaqsRepository {

    public init() { }

    public func insert(name: String, value: String) async throws -> [String: String] {
        [:]
    }

    public func remove(name: String) async throws -> [String: String] {
        [:]
    }

    public func getAll() async throws -> [String : String] {
        ["Working Directory": "Test working directory help"]
    }
}
