import Logging
import AsyncHTTPClient
import SotoS3

actor DefaultCacheService: CacheService {

    var cacheRepo: S3CacheRepository!
    let logger = Logger(label: "DefaultCacheService")

    private init() { }

    static let shared = DefaultCacheService()

    func initialize(httpClient: HTTPClient) {
        let awsClient = AWSClient(httpClientProvider: .shared(httpClient))
        self.cacheRepo = .init(awsClient: awsClient, logger: self.logger)
    }

    /// Get the storage from the repository and then delete it from the repository.
    func getAndPopulate() async {
        do {
            let storage = try await self.cacheRepo.get()
            await storage.populateServices()
            self.delete()
        } catch {
            logger.report("Couldn't get CacheStorage", error: error)
        }
    }

    /// Delete the object from the repository.
    /// We don't care if it succeeds or not.
    private func delete() {
        Task {
            do {
                try await self.cacheRepo.delete()
            } catch {
                logger.report("Couldn't delete CacheStorage", error: error)
            }
        }
    }

    /// Save the storage to the repository.
    func makeAndSave() async {
        do {
            let storage = await CacheStorage.makeFromCachedData()
            try await self.cacheRepo.save(storage: storage)
        } catch {
            logger.report("Couldn't save CacheStorage", error: error)
        }
    }
}
