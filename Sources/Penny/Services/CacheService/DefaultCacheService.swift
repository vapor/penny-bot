import Logging
import AsyncHTTPClient
import SotoS3

actor DefaultCachesService: CachesService {
    var cacheRepo: S3CacheRepository!
    let logger = Logger(label: "DefaultCachesService")

    private init() { }

    static let shared = DefaultCachesService()

    func initialize(awsClient: AWSClient) {
        self.cacheRepo = .init(awsClient: awsClient, logger: self.logger)
    }

    /// Get the storage from the repository and then delete it from the repository.
    func getCachedInfoFromRepositoryAndPopulateServices() async {
        do {
            let storage = try await self.cacheRepo.get()
            await storage.populateServicesAndReport()
            self.delete()
        } catch {
            logger.report("Couldn't get CachesStorage", error: error)
        }
    }

    /// Delete the object from the repository.
    /// We don't care if it succeeds or not.
    private func delete() {
        Task {
            do {
                try await self.cacheRepo.delete()
            } catch {
                logger.report("Couldn't delete CachesStorage", error: error)
            }
        }
    }

    /// Save the storage to the repository.
    func gatherCachedInfoAndSaveToRepository() async {
        do {
            let storage = await CachesStorage.makeFromCachedData()
            try await self.cacheRepo.save(storage: storage)
        } catch {
            logger.report("Couldn't save CachesStorage", error: error)
        }
    }
}
