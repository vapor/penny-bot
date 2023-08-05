@testable import Penny
import Models
import AsyncHTTPClient

public actor FakeAutoFaqsService: AutoFaqsService {

    public init() { }

    private let all = ["PostgresNIO.PSQLError": "Update your PostgresNIO!"]

    var responseRateLimiter = DefaultAutoFaqsService.ResponseRateLimiter()

    public func canRespond(receiverID: UserSnowflake, faqHash: Int) async -> Bool {
        responseRateLimiter.canRespond(to: .init(
            receiverID: receiverID,
            faqHash: faqHash
        ))
    }

    public func insert(expression: String, value: String) async throws { }

    public func remove(expression: String) async throws { }

    public func get(expression: String) async throws -> String? {
        self.all[expression]
    }

    public func getName(hash: Int) async throws -> String? {
        self.all.first(where: { $0.key.hash == hash })?.key
    }

    public func getAll() async throws -> [String: String] {
        self.all
    }

    public func getAllFolded() async throws -> [String: String] {
        Dictionary(uniqueKeysWithValues: self.all.map({ ($0.key.superHeavyFolded(), $0.value) }))
    }
}
