
protocol CacheService {
    func getAndPopulate() async
    func makeAndSave() async
}
