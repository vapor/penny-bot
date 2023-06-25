import PennyModels

public protocol FaqsRepository {

    func insert(name: String, value: String) async throws -> [String: String]

    func remove(name: String) async throws -> [String: String]

    func getAll() async throws -> [String: String]
}
