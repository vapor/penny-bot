import PennyModels

protocol HelpsService {
    func exists(name: String) async throws -> Bool
    func insert(name: String, value: String) async throws
    func remove(name: String) async throws
    func get(name: String) async throws -> String?
    func getAll() async throws -> [String: String]
}
