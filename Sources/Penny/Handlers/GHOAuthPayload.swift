/// This file is duplicated in Lambdas/GHOAuth/Models, so make sure to edit both copies.

import DiscordBM
import JWTKit

/// This Payload will get sent along with the OAuth redirect to the GitHub OAuth page,
/// specifically inside the `state` query parameter.
/// This is used to verify the user's identity when they come back from GitHub 
/// and that the request is not forged.
public struct GHOAuthPayload: JWTPayload {
    public let discordID: UserSnowflake
    public let interactionToken: String
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
