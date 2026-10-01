public import NewCodable

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

extension UUID: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeString(self.uuidString)
    }
}

extension UUID: JSONDecodable {
    public static func decode(
        from decoder: inout some JSONDecoderProtocol & ~Escapable
    ) throws(CodingError.Decoding) -> Self {
        let uuidString = try decoder.decode(String.self)
        guard let uuid = UUID(uuidString: uuidString) else {
            throw CodingError.dataCorrupted(debugDescription: "Attempted to decode UUID from invalid UUID string.")
        }
        return uuid
    }
}
