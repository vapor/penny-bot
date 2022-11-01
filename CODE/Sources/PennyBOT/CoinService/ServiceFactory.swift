import AsyncHTTPClient
import Logging

public enum ServiceFactory {
    public static var makeCoinService: (HTTPClient, Logger) -> any CoinService = {
        DefaultCoinService(httpClient: $0, logger: $1)
    }
}
