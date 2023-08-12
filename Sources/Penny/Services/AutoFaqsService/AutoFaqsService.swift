import AsyncHTTPClient
import DiscordModels
import Models

protocol AutoFaqsService: Sendable {
    func insert(expression: String, value: String) async throws
    func remove(expression: String) async throws
    func get(expression: String) async throws -> String?
    func getName(hash: Int) async throws -> String?
    func getAll() async throws -> [String: String]
    func getAllFolded() async throws -> [String: String]
    func canRespond(receiverID: UserSnowflake, faqHash: Int) async -> Bool
    func consumeCachesStorageData(_ storage: DefaultAutoFaqsService.ResponseRateLimiter) async
    func getCachedDataForCachesStorage() async -> DefaultAutoFaqsService.ResponseRateLimiter
}
