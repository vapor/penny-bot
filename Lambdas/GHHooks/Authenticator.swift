import JWTKit
import GitHubAPI
import OpenAPIRuntime
import AsyncHTTPClient
import OpenAPIAsyncHTTPClient
import Logging
import struct DiscordModels.Secret

actor Authenticator {
    private let secretsRetriever: SecretsRetriever
    private let httpClient: HTTPClient
    let logger: Logger

    /// The cached access token.
    private var cachedAccessToken: InstallationToken?

    private let lock = ActorLock()

    init(secretsRetriever: SecretsRetriever, httpClient: HTTPClient, logger: Logger) {
        self.secretsRetriever = secretsRetriever
        self.httpClient = httpClient
        self.logger = logger
    }

    /// TODO: Actually "refresh" the token if needed and possible,
    /// instead of just creating a new one.
    func generateAccessToken(forceRefreshToken: Bool = false) async throws -> Secret {
        try await lock.withLock {
            if !forceRefreshToken,
               let cachedAccessToken = await cachedAccessToken {
                return Secret(cachedAccessToken.token)
            } else {
                let token = try await makeJWTToken()
                let client = try await makeClient(token: token)
                let accessToken = try await createAccessToken(client: client)
                await setCachedAccessToken(to: accessToken)
                return Secret(accessToken.token)
            }
        }
    }

    private func createAccessToken(client: Client) async throws -> InstallationToken {
        let response = try await client.apps_create_installation_access_token(.init(
            path: .init(installation_id: Constants.pennyGitHubAppID)
        ))

        if case let .created(created) = response,
           case let .json(json) = created.body {
            return json
        } else {
            throw Errors.httpRequestFailed(response: response)
        }
    }

    private func makeClient(token: Secret) throws -> Client {
        let transport = AsyncHTTPClientTransport(configuration: .init(
            client: httpClient,
            timeout: .seconds(3)
        ))
        let middleware = GHMiddleware(
            authorization: .bearer(token),
            logger: logger
        )
        let client = Client(
            serverURL: try Servers.server1(),
            transport: transport,
            middlewares: [middleware]
        )
        return client
    }

    private func makeJWTToken() async throws -> Secret {
        let signers = JWTSigners()
        let key = try await getPrivKey()
        try signers.use(.rs256(key: .private(pem: key.value)))
        let payload = TokenPayload()
        let token = try signers.sign(payload)
        return Secret(token)
    }

    private func getPrivKey() async throws -> Secret {
        try await secretsRetriever.getSecret(arnEnvVarKey: "GH_APP_AUTH_PRIV_KEY")
    }

    private func setCachedAccessToken(to token: InstallationToken) {
        self.cachedAccessToken = token
    }
}

/// https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app#about-json-web-tokens-jwts
private struct TokenPayload: JWTPayload, Equatable {
    /// When the token was issued.
    let issuedAt: IssuedAtClaim
    /// When the token will expire.
    let expiresAt: IntExpirationClaim
    /// Penny's GitHub app-id.
    let issuer: String
    /// The algorithm. GitHub says `RS256`.
    let algorithm: String

    enum CodingKeys: String, CodingKey {
        case issuedAt = "iat"
        case expiresAt = "exp"
        case issuer = "iss"
        case algorithm = "alg"
    }

    init() {
        /// 60s in the past, per GitHub docs.
        self.issuedAt = .init(value: Date().addingTimeInterval(-60))
        /// 5 mins into the future. GitHub docs says no more than 10 mins.
        self.expiresAt = .init(value: Date().addingTimeInterval(5 * 60))
        /// The app-id, per GitHub docs.
        self.issuer = "\(Constants.pennyGitHubAppID)"
        /// `RS256`, per GitHub docs.
        self.algorithm = "RS256"
    }

    // Run any additional verification logic beyond
    // signature verification here.
    // Since we have an ExpirationClaim, we will
    // call its verify method.
    func verify(using signer: JWTSigner) throws {
        try self.expiresAt.verifyNotExpired()
    }
}

struct IntExpirationClaim: JWTClaim, Equatable {
    var value: Date

    init(value: Date) {
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = Date(timeIntervalSince1970: Double(try container.decode(Int.self)))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Int(self.value.timeIntervalSince1970))
    }

    /// Throws an error if the claim's date is later than current date.
    func verifyNotExpired(currentDate: Date = .init()) throws {
        switch self.value.compare(currentDate) {
        case .orderedAscending, .orderedSame:
            throw JWTError.claimVerificationFailure(name: "exp", reason: "expired")
        case .orderedDescending:
            break
        }
    }
}
