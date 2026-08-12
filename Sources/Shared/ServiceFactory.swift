package import class AsyncHTTPClient.HTTPClient

package enum ServiceFactory {
    package static func makeUsersService(httpClient: HTTPClient, invoker: LambdaInvoker) -> any UsersService {
        DefaultUsersService(httpClient: httpClient, invoker: invoker)
    }
}
