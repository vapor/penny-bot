import AsyncHTTPClient
import Logging
import PennyModels

public protocol CoinService {
    func postCoin(with coinRequest: CoinRequest) async throws -> CoinResponse
}
