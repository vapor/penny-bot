import JWTKit
import GitHubAPI
import OpenAPIRuntime
import AsyncHTTPClient
import OpenAPIAsyncHTTPClient
import Logging
import LambdasShared
import Shared
import Foundation

actor Authenticator {
    private let secretsRetriever: SecretsRetriever
    private let httpClient: HTTPClient
    let logger: Logger

    /// The cached access token.
    private var cachedAccessToken: InstallationToken?

    private let queue = SerialProcessor()

    init(secretsRetriever: SecretsRetriever, httpClient: HTTPClient, logger: Logger) {
        self.secretsRetriever = secretsRetriever
        self.httpClient = httpClient
        self.logger = logger
    }

    /// TODO: Actually "refresh" the token if needed and possible,
    /// instead of just creating a new one.
    /// This requires having a more persistent caching mechanism to cache the token
    /// across different lambda processes, so it is possible for the installation token to
    /// live long enough to be expired in the first place, so then we can think of refreshing it.
    func generateAccessToken(forceRefreshToken: Bool = false) async throws -> String {
        try await queue.process {
            if !forceRefreshToken,
               let cachedAccessToken = await cachedAccessToken {
                return cachedAccessToken.token
            } else {
                let token = try await makeJWTToken()
                let client = try await makeClient(token: token)
                let accessToken = try await createAccessToken(client: client)
                await setCachedAccessToken(to: accessToken)
                return accessToken.token
            }
        }
    }

    private func createAccessToken(client: Client) async throws -> InstallationToken {
        let response = try await client.apps_create_installation_access_token(.init(
            path: .init(installation_id: Constants.GitHub.installationID)
        ))

        if case let .created(created) = response,
           case let .json(json) = created.body {
            return json
        } else {
            throw Errors.httpRequestFailed(response: response)
        }
    }

    private func makeClient(token: String) throws -> Client {
        try .makeForGitHub(
            httpClient: httpClient,
            authorization: .bearer(token),
            logger: logger
        )
    }

    private func makeJWTToken() async throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .integerSecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .integerSecondsSince1970
        let signers = JWTSigners(
            defaultJSONEncoder: encoder,
            defaultJSONDecoder: decoder
        )
        let key = try await getPrivKey()
        try signers.use(.rs256(key: .private(pem: key)))
        let payload = TokenPayload()
        let token = try signers.sign(payload)
        return token
    }

    private func getPrivKey() async throws -> String {
        try await secretsRetriever.getSecret(arnEnvVarKey: "GH_APP_AUTH_PRIV_KEY_ARN")
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
        self.issuer = "\(Constants.GitHub.appID)"
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
