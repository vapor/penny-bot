@testable import Penny
import Models
import AsyncHTTPClient

package actor FakeAutoFaqsService: AutoFaqsService {

    package typealias ResponseRateLimiter = DefaultAutoFaqsService.ResponseRateLimiter

    package init() { }

    private let all = ["PostgresNIO.PSQLError": "Update your PostgresNIO!"]

    var responseRateLimiter = ResponseRateLimiter()

    package func insert(expression: String, value: String) async throws { }

    package func remove(expression: String) async throws { }

    package func get(expression: String) async throws -> String? {
        self.all[expression]
    }

    package func getName(hash: Int) async throws -> String? {
        self.all.first(where: { $0.key.hash == hash })?.key
    }

    package func getAll() async throws -> [String: String] {
        self.all
    }

    package func getAllFolded() async throws -> [String: String] {
        Dictionary(uniqueKeysWithValues: self.all.map({ ($0.key.superHeavyFolded(), $0.value) }))
    }

    package func canRespond(receiverID: UserSnowflake, faqHash: Int) async -> Bool {
        responseRateLimiter.canRespond(to: .init(
            receiverID: receiverID,
            faqHash: faqHash
        ))
    }

    package func consumeCachesStorageData(_ storage: ResponseRateLimiter) async {
        self.responseRateLimiter = storage
    }

    package func getCachedDataForCachesStorage() async -> ResponseRateLimiter {
        return self.responseRateLimiter
    }
}
