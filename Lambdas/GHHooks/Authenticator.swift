import JWTKit
import GithubAPI
import OpenAPIRuntime
import AsyncHTTPClient
import OpenAPIAsyncHTTPClient
import Logging
import struct DiscordModels.Secret

struct Authenticator {
    private let secretsRetriever: SecretsRetriever
    private let httpClient: HTTPClient
    private let logger: Logger

    init(secretsRetriever: SecretsRetriever, httpClient: HTTPClient, logger: Logger) {
        self.secretsRetriever = secretsRetriever
        self.httpClient = httpClient
        self.logger = logger
    }

    func generateAccessToken() async throws -> String {
        let token = try await makeJWTToken()
        let client = try makeClient(token: token)
        let accessToken = try await createAccessToken(client: client)
        return accessToken
    }

    private func createAccessToken(client: Client) async throws -> String {
        let response = try await client.apps_create_installation_access_token(.init(
            path: .init(installation_id: Constants.pennyGitHubAppID)
        ))

        switch response {
        case let .created(created):
            switch created.body {
            case let .json(json):
                /// FIXME: take care of refreshing the token and stuff
                /// When we get back a 403, we should refresh the token and retry request
                return json.token
            }
        default:
            throw Errors.httpRequestFailed(response: response)
        }
    }

    private func makeClient(token: String) throws -> Client {
        let transport = AsyncHTTPClientTransport(configuration: .init(
            client: httpClient,
            timeout: .seconds(3)
        ))
        let middleware = GHMiddleware(
            secretsRetriever: secretsRetriever,
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

    private func makeJWTToken() async throws -> String {
        let signers = JWTSigners()
        let key = try await getPrivKey()
        try signers.use(.rs256(key: .private(pem: key.value)))
        let payload = TokenPayload()
        let token = try signers.sign(payload)
        return token
    }

    private func getPrivKey() async throws -> Secret {
        try await secretsRetriever.getSecret(arnEnvVarKey: "GH_APP_AUTH_PRIV_KEY")
    }
}


/// https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app#about-json-web-tokens-jwts
private struct TokenPayload: JWTPayload, Equatable {
    /// When the token was issued.
    let issuedAt: IssuedAtClaim
    /// When the token will expire.
    let expiresAt: ExpirationClaim
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
