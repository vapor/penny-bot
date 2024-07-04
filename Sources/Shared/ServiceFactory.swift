import AsyncHTTPClient

package enum ServiceFactory {
    package static func makeUsersService(httpClient: HTTPClient, apiBaseURL: String) -> any UsersService {
        DefaultUsersService(httpClient: httpClient, apiBaseURL: apiBaseURL)
    }
}
