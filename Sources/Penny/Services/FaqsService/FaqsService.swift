import Models
import AsyncHTTPClient

protocol FaqsService: Sendable {
    func initialize(httpClient: HTTPClient) async
    func insert(name: String, value: String) async throws
    func remove(name: String) async throws
    func get(name: String) async throws -> String?
    func getName(hash: Int) async throws -> String?
    func getAll() async throws -> [String: String]
}
