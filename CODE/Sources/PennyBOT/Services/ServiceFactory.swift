import AsyncHTTPClient
import Logging

enum ServiceFactory {
    static var makeCoinService: (HTTPClient, Logger) -> any CoinService = {
        DefaultCoinService(httpClient: $0, logger: $1)
    }
    
    static var makePingsService: () -> any AutoPingsService = {
        DefaultPingsService.shared
    }
}
