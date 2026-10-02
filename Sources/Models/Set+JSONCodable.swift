public import NewCodable

extension Set: JSONEncodable where Element: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeArray { arrayEncoder throws(CodingError.Encoding) in
            for element in self {
                try arrayEncoder.encode(element)
            }
        }
    }
}

extension Set: JSONDecodable where Element: JSONDecodable {
    public static func decode(
        from decoder: inout some JSONDecoderProtocol & ~Escapable
    ) throws(CodingError.Decoding) -> Self {
        try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
            var set = Self()
            try arrayDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                try set.insert(elementDecoder.decode(Element.self))
            }
            return set
        }
    }
}
