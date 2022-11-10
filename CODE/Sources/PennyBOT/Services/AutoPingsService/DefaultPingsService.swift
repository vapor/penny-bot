import PennyRepositories
import PennyModels
import AsyncHTTPClient
import Foundation
import Logging

actor DefaultPingsService: AutoPingsService {
    
    var httpClient: HTTPClient!
    var logger: Logger!
    lazy var pingsRepo = RepositoryFactory.makeAutoPingsRepository(logger)
    
    var lastUpdate = Date()
    var cachedItems: S3AutoPingItems?
    var resetItemsTask: Task<(), Never>?
    
    private init() { }
    
    static let shared = DefaultPingsService()
    
    func initialize(httpClient: HTTPClient, logger: Logger) {
        self.httpClient = httpClient
        self.logger = logger
        self.setUpResetItemsTask()
    }
    
    func insert(_ text: String, forDiscordID id: String) async throws {
        var request = HTTPClientRequest(url: "\(Constants.coinServiceBaseUrl!)/\(id)")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try JSONEncoder().encode(AutoPingRequest(text: text))
        request.body = .bytes(data)
        let response = try await httpClient.execute(
            request,
            timeout: .seconds(30),
            logger: self.logger
        )
        logger.trace("HTTP head \(response)")
        
        guard (200..<300).contains(response.status.code) else {
            logger.error("Post-coin failed. Response: \(response)")
            throw ServiceError.badStatus
        }
        
        let body = try await response.body.collect(upTo: 1024 * 1024 * 64)
        let items = try JSONDecoder().decode(S3AutoPingItems.self, from: body)
        freshenCache(items)
    }
    
    func remove(_ text: String, forDiscordID id: String) async throws {
        var request = HTTPClientRequest(url: "\(Constants.coinServiceBaseUrl!)/\(id)")
        request.method = .DELETE
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try JSONEncoder().encode(AutoPingRequest(text: text))
        request.body = .bytes(data)
        let response = try await httpClient.execute(
            request,
            timeout: .seconds(30),
            logger: self.logger
        )
        logger.trace("HTTP head \(response)")
        
        guard (200..<300).contains(response.status.code) else {
            logger.error("Post-coin failed. Response: \(response)")
            throw ServiceError.badStatus
        }
        
        let body = try await response.body.collect(upTo: 1024 * 1024 * 64)
        let items = try JSONDecoder().decode(S3AutoPingItems.self, from: body)
        freshenCache(items)
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
            var request = HTTPClientRequest(url: "\(Constants.coinServiceBaseUrl!)/all")
            request.method = .GET
            let response = try await httpClient.execute(
                request,
                timeout: .seconds(30),
                logger: self.logger
            )
            logger.trace("HTTP head \(response)")
            
            guard (200..<300).contains(response.status.code) else {
                logger.error("Post-coin failed. Response: \(response)")
                throw ServiceError.badStatus
            }
            let body = try await response.body.collect(upTo: 1024 * 1024 * 64)
            let items = try JSONDecoder().decode(S3AutoPingItems.self, from: body)
            freshenCache(items)
            return items
        }
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
