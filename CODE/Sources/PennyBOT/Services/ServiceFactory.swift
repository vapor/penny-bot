import AsyncHTTPClient
import Logging

enum ServiceFactory {
    static var makeCoinService: () -> any CoinService = {
        DefaultCoinService.shared
    }
    
    static var makePingsService: () -> any AutoPingsService = {
        DefaultPingsService.shared
    }

    static var makeHelpsService: () -> any HelpsService = {
        DefaultHelpsService.shared
    }
}
