import Logging
import AsyncHTTPClient
import SotoS3

actor DefaultCachesService: CachesService {
    var cachesRepo: S3CachesRepository!
    let logger = Logger(label: "DefaultCachesService")

    private init() { }

    static let shared = DefaultCachesService()

    func initialize(awsClient: AWSClient) {
        self.cachesRepo = .init(awsClient: awsClient, logger: self.logger)
    }

    /// Get the storage from the repository and then delete it from the repository.
    func getCachedInfoFromRepositoryAndPopulateServices(
        proposalsChecker: ProposalsChecker
    ) async {
        do {
            let storage = try await self.cachesRepo.get()
            await storage.populateServicesAndReport(proposalsChecker: proposalsChecker)
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
    func gatherCachedInfoAndSaveToRepository(proposalsChecker: ProposalsChecker) async {
        do {
            let storage = await CachesStorage.makeFromCachedData(
                proposalsChecker: proposalsChecker
            )
            try await self.cachesRepo.save(storage: storage)
        } catch {
            logger.report("Couldn't save CachesStorage", error: error)
        }
    }
}
