import PennyModels

protocol CoinService: Sendable {
    func postCoin(with coinRequest: CoinRequest) async throws -> CoinResponse
}
