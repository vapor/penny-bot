package import class AsyncHTTPClient.HTTPClient

package enum ServiceFactory {
    package static func makeUsersService(httpClient: HTTPClient, apiBaseURL: String) -> any UsersService {
        DefaultUsersService(httpClient: httpClient, apiBaseURL: apiBaseURL)
    }
}
