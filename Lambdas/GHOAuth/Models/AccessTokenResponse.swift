import NewCodable

@JSONDecodable
struct AccessTokenResponse {
    @CodingKey("access_token")
    let accessToken: String
    let scope: String
    @CodingKey("token_type")
    let tokenType: String
}
