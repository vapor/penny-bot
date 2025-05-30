import AsyncHTTPClient
/// Import full foundation even on linux for `hash`, for now.
import Foundation
import Models

@testable import Penny

actor FakeAutoFaqsService: AutoFaqsService {

    typealias ResponseRateLimiter = DefaultAutoFaqsService.ResponseRateLimiter

    init() {}

    private let all = ["PostgresNIO.PSQLError": "Update your PostgresNIO!"]

    var responseRateLimiter = ResponseRateLimiter()

    func insert(expression: String, value: String) async throws {}

    func remove(expression: String) async throws {}

    func get(expression: String) async throws -> String? {
        self.all[expression]
    }

    func getName(hash: Int) async throws -> String? {
        self.all.first(where: { $0.key.hash == hash })?.key
    }

    func getAll() async throws -> [String: String] {
        self.all
    }

    func getAllFolded() async throws -> [String: String] {
        Dictionary(uniqueKeysWithValues: self.all.map({ ($0.key.superHeavyFolded(), $0.value) }))
    }

    func canRespond(receiverID: UserSnowflake, faqHash: Int) async -> Bool {
        responseRateLimiter.canRespond(
            to: .init(
                receiverID: receiverID,
                faqHash: faqHash
            )
        )
    }

    func consumeCachesStorageData(_ storage: ResponseRateLimiter) async {
        self.responseRateLimiter = storage
    }

    func getCachedDataForCachesStorage() async -> ResponseRateLimiter {
        self.responseRateLimiter
    }
}
