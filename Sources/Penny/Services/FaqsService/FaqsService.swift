import AsyncHTTPClient
import Models

protocol FaqsService: Sendable {
    func insert(name: String, value: String) async throws
    func remove(name: String) async throws
    func get(name: String) async throws -> String?
    func getName(hash: Int) async throws -> String?
    func getAll() async throws -> [String: String]
}
