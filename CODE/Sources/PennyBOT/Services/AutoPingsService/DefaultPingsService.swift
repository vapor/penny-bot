import PennyRepositories
import PennyModels
import AsyncHTTPClient
import Foundation
import Logging
import NIOHTTP1

actor DefaultPingsService: AutoPingsService {
    
    var httpClient: HTTPClient!
    var logger: Logger!
    
    var cachedItems: S3AutoPingItems?
    var resetItemsTask: Task<(), Never>?
    
    private init() { }
    
    static let shared = DefaultPingsService()
    
    func initialize(httpClient: HTTPClient, logger: Logger) {
        self.httpClient = httpClient
        self.logger = logger
        self.setUpResetItemsTask()
    }
    
    func insert(_ texts: [String], forDiscordID id: String) async throws {
        try await self.send(
            pathParameter: id,
            method: .PUT,
            pingRequest: .init(texts: texts)
        )
    }
    
    func remove(_ texts: [String], forDiscordID id: String) async throws {
        try await self.send(
            pathParameter: id,
            method: .DELETE,
            pingRequest: .init(texts: texts)
        )
    }
    
    func get(discordID id: String) async throws -> [S3AutoPingItems.Expression] {
        try await self.getAll()
            .items
            .filter { $0.value.contains(id) }
            .compactMap { $0.key }
            .sorted { $0.innerValue > $1.innerValue }
            .sorted { $0.innerValue.count < $1.innerValue.count }
    }
    
    func getAll() async throws -> S3AutoPingItems {
        if let cachedItems = cachedItems {
            return cachedItems
        } else {
            return try await self.send(
                pathParameter: "all",
                method: .GET,
                pingRequest: nil
            )
        }
    }
    
    @discardableResult
    func send(
        pathParameter: String,
        method: HTTPMethod,
        pingRequest: AutoPingRequest?
    ) async throws -> S3AutoPingItems {
        let url = Constants.pingsServiceBaseUrl + "/" + pathParameter
        var request = HTTPClientRequest(url: url)
        request.method = method
        if let pingRequest {
            request.headers.add(name: "Content-Type", value: "application/json")
            let data = try JSONEncoder().encode(pingRequest)
            request.body = .bytes(data)
        }
        let response = try await httpClient.execute(
            request,
            timeout: .seconds(30),
            logger: self.logger
        )
        logger.trace("HTTP head \(response)")
        
        guard (200..<300).contains(response.status.code) else {
            logger.error("PingsService failed. Response: \(response)")
            throw ServiceError.badStatus
        }
        
        let body = try await response.body.collect(upTo: 1024 * 1024 * 64)
        let items = try JSONDecoder().decode(S3AutoPingItems.self, from: body)
        freshenCache(items)
        resetItemsTask?.cancel()
        return items
    }
    
    private func freshenCache(_ new: S3AutoPingItems) {
        self.cachedItems = new
        self.resetItemsTask?.cancel()
    }
    
    private func setUpResetItemsTask() {
        self.resetItemsTask?.cancel()
        self.resetItemsTask = Task {
            if (try? await Task.sleep(for: .seconds(60 * 30))) != nil {
                self.cachedItems = nil
                self.setUpResetItemsTask()
            } else {
                /// If canceled, set up the task again.
                /// This way, the functions above can cancel this when they've got fresh items
                /// and this will just reschedule itself for another later time.
                self.setUpResetItemsTask()
            }
        }
    }
}
