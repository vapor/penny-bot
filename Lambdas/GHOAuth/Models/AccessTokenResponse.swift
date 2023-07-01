struct AccessTokenResponse: Decodable {
    let accessToken: String
    let scope: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case scope
        case tokenType = "token_type"
    }
}
