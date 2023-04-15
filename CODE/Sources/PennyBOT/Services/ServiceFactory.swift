import AsyncHTTPClient
import Logging

enum ServiceFactory {
    static var makeCoinService: (HTTPClient) -> any CoinService = {
        DefaultCoinService(httpClient: $0)
    }
    
    static var makePingsService: () -> any AutoPingsService = {
        DefaultPingsService.shared
    }

    static var makeHelpsService: () -> any HelpsService = {
        DefaultHelpsService.shared
    }
}
