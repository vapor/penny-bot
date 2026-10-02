public import DiscordModels
public import NewCodable

extension Snowflake: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeString(self.rawValue)
    }
}

extension Snowflake: JSONDecodable {
    public static func decode(
        from decoder: inout some JSONDecoderProtocol & ~Escapable
    ) throws(CodingError.Decoding) -> Self {
        try Self(decoder.decode(String.self))
    }
}
