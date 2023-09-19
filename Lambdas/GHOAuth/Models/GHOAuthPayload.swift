import DiscordBM
import JWTKit

/// This Payload will get sent along with the OAuth redirect to the GitHub OAuth page,
/// specifically inside the `state` query parameter.
public struct GHOAuthPayload: JWTPayload {
    /// Used to verify the user's identity when they come back from GitHub.
    public let discordID: UserSnowflake
    /// The interaction token to respond back to user on Discord with and notify of the result.
    public let interactionToken: String
    /// Expiration time of the token.
    public let expiration: ExpirationClaim

    public init(discordID: UserSnowflake, interactionToken: String) {
        self.discordID = discordID
        self.interactionToken = interactionToken
        self.expiration = .init(value: Date().addingTimeInterval(10 * 60)) // 10 minutes
    }

    public func verify(using signer: JWTSigner) throws {
        try self.expiration.verifyNotExpired()
    }
}
