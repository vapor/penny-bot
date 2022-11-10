@testable import PennyBOT
import PennyModels

public struct FakeCoinService: CoinService {
    
    public init() { }
    
    public func postCoin(with coinRequest: CoinRequest) async throws -> CoinResponse {
        CoinResponse(
            sender: coinRequest.from,
            receiver: coinRequest.receiver,
            coins: coinRequest.amount + .random(in: 0..<10_000)
        )
    }
}
