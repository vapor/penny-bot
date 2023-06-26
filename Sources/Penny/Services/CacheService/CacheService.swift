
protocol CacheService {
    func getAndFlush() async -> CacheStorage
    func save(storage: CacheStorage) async
}
