import Logging
import AsyncHTTPClient
import SotoS3

actor DefaultCachesService: CachesService {
    let cachesRepo: S3CachesRepository
    let context: CachesStorage.Context
    let logger = Logger(label: "DefaultCachesService")

    init(awsClient: AWSClient, context: CachesStorage.Context) {
        self.cachesRepo = .init(awsClient: awsClient, logger: self.logger)
        self.context = context
    }

    /// Get the storage from the repository and then delete it from the repository.
    func getCachedInfoFromRepositoryAndPopulateServices() async {
        do {
            let storage = try await self.cachesRepo.get()
            await storage.populateServicesAndReport(context: context)
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
                try await self.cachesRepo.delete()
            } catch {
                logger.report("Couldn't delete CachesStorage", error: error)
            }
        }
    }

    /// Save the storage to the repository.
    func gatherCachedInfoAndSaveToRepository() async {
        do {
            let storage = await CachesStorage.makeFromCachedData(context: context)
            try await self.cachesRepo.save(storage: storage)
        } catch {
            logger.report("Couldn't save CachesStorage", error: error)
        }
    }
}
