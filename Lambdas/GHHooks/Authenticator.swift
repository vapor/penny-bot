import JWTKit
import struct DiscordModels.Secret

struct Authenticator {
    let secretesRetriever: SecretsRetriever

    /// FIXME: set the env var `GH_APP_AUTH_PRIV_KEY` to `arn:aws:secretsmanager:eu-west-1:177420307256:secret:prod/penny/penny-bot/github-penny-app-private-key-vhi2WZ`.
    func getPrivKey() async throws -> Secret {
        try await secretesRetriever.getSecret(arnEnvVarKey: "GH_APP_AUTH_PRIV_KEY")
    }
}


/// https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app#about-json-web-tokens-jwts
private struct TokenPayload: JWTPayload, Equatable {
    var issuedAt: IssuedAtClaim
    var expiresAt: ExpirationClaim
    /// Penny's GitHub app-id.
    var issuer: String
    /// The algorithm. GitHub says `RS256`.
    var algorithm: String

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
        self.issuer = "360798"
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
