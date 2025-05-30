package import DiscordBM
package import JWTKit

#if canImport(FoundationEssentials)
import struct FoundationEssentials.Date
#else
import struct Foundation.Date
#endif

/// This Payload will get sent along with the OAuth redirect to the GitHub OAuth page,
/// specifically inside the `state` query parameter.
package struct GHOAuthPayload: JWTPayload {
    /// Used to verify the user's identity when they come back from GitHub.
    package let discordID: UserSnowflake
    /// The interaction token to respond back to user on Discord with and notify of the result.
    package let interactionToken: String
    /// Expiration time of the token.
    package let expiration: ExpirationClaim

    package init(discordID: UserSnowflake, interactionToken: String) {
        self.discordID = discordID
        self.interactionToken = interactionToken
        self.expiration = .init(value: Date().addingTimeInterval(10 * 60))  // 10 minutes
    }

    package func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}
