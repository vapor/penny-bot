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
    private var cachedAccessToken: Secret?

    private let lock = ActorLock()

    init(secretsRetriever: SecretsRetriever, httpClient: HTTPClient, logger: Logger) {
        self.secretsRetriever = secretsRetriever
        self.httpClient = httpClient
        self.logger = logger
    }

    func generateAccessToken(forceRefreshToken: Bool = false) async throws -> Secret {
        try await lock.withLock {
            if !forceRefreshToken,
               let cachedAccessToken = await cachedAccessToken {
                return cachedAccessToken
            } else {
                let token = try await makeJWTToken()
                logger.trace("Made a JWT token: \(token.value.debugDescription)")
                await setCachedAccessToken(to: token)
                return token
            }
        }
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

    private func setCachedAccessToken(to token: Secret) {
        self.cachedAccessToken = token
    }
}

/// https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app#about-json-web-tokens-jwts
private struct TokenPayload: JWTPayload, Equatable {
    /// When the token was issued.
    let issuedAt: IntIssuedAtClaim
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

/// The "exp" (expiration time) claim identifies the expiration time on
/// or after which the JWT MUST NOT be accepted for processing.  The
/// processing of the "exp" claim requires that the current date/time
/// MUST be before the expiration date/time listed in the "exp" claim.
/// Implementers MAY provide for some small leeway, usually no more than
/// a few minutes, to account for clock skew.  Its value MUST be a number
/// containing a NumericDate value.  Use of this claim is OPTIONAL.
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

/// The "iat" (issued at) claim identifies the time at which the JWT was
/// issued.  This claim can be used to determine the age of the JWT.  Its
/// value MUST be a number containing a NumericDate value.  Use of this
/// claim is OPTIONAL.
struct IntIssuedAtClaim: JWTUnixEpochClaim, Equatable {
    /// See `JWTClaim`.
    var value: Date

    /// See `JWTClaim`.
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
}
