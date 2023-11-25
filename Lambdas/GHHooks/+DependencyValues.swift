import Dependencies
import GitHubAPI
import AsyncHTTPClient
import DiscordBM
import Rendering
import Logging
import Shared

extension DependencyValues {
    var eventName: GHEvent.Kind {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    var event: GHEvent {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    var httpClient: HTTPClient {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    var discordClient: any DiscordClient {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    var githubClient: Client {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    var renderClient: RenderClient {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    var messageLookupRepo: any MessageLookupRepo {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    var usersService: any UsersService {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    var requester: Requester {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    var logger: Logger {
        get { self[GenericKey.self] }
        set { self[GenericKey.self] = newValue }
    }

    private enum GenericKey<Value: Sendable>: DependencyKey {
        static var liveValue: Value {
            fatalError("Dependency of type \(Value.self) was not available")
        }
    }
}
