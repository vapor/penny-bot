import AsyncHTTPClient

public enum ServiceFactory {
    public static func makeUsersService(httpClient: HTTPClient, apiBaseURL: String) -> any UsersService {
        DefaultUsersService(httpClient: httpClient, apiBaseURL: apiBaseURL)
    }
}
