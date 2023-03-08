import PennyModels

protocol CoinService {
    func postCoin(with coinRequest: CoinRequest) async throws -> CoinResponse
}
