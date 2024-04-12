import AsyncHTTPClient

package enum ServiceFactory {
    package static func makeUsersService(apiBaseURL: String) -> any UsersService {
        DefaultUsersService(apiBaseURL: apiBaseURL)
    }
}
