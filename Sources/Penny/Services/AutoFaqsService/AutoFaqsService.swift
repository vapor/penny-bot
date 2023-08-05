import Models
import DiscordModels
import AsyncHTTPClient

protocol AutoFaqsService: Sendable {
    func canRespond(receiverID: UserSnowflake, faqHash: Int) async -> Bool
    func insert(expression: String, value: String) async throws
    func remove(expression: String) async throws
    func get(expression: String) async throws -> String?
    func getName(hash: Int) async throws -> String?
    func getAll() async throws -> [String: String]
    func getAllFolded() async throws -> [String: String]
}
