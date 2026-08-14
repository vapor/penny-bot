import Crypto

#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package enum Verifier {

    package enum Errors: Error, CustomStringConvertible {
        case signaturesDoNotMatch(header: String, expected: String)

        package var description: String {
            switch self {
            case let .signaturesDoNotMatch(header, expected):
                return "signaturesDoNotMatch(header: \(header), expected: \(expected)"
            }
        }
    }

    package static func verifyWebhookSignature(
        signatureHeader: String,
        requestBody: Data,
        secret: String
    ) throws {
        let secret = SymmetricKey(data: Data(secret.utf8))
        var hmac = HMAC<SHA256>.init(key: secret)
        hmac.update(data: requestBody)
        let mac = hmac.finalize()
        let expectedSignature = "sha256=\(mac.toHexDigest())"
        guard signatureHeader == expectedSignature else {
            throw Errors.signaturesDoNotMatch(header: signatureHeader, expected: expectedSignature)
        }
    }
}

extension ContiguousBytes {
    /// Returns a hex-encoded `String` buffer from an array of bytes.
    func toHexDigest() -> String {
        self.withUnsafeBytes { bytes in
            bytes.withMemoryRebound(to: UInt8.self) { bytes in
                let span = bytes.span
                return String(unsafeUninitializedCapacity: span.count * 2) { buffer in
                    for index in span.indices {
                        buffer[index * 2] = hexLowercasedDigits[Int(bytes[index] >> 4)]
                        buffer[index * 2 + 1] = hexLowercasedDigits[Int(bytes[index] & 0xF)]
                    }
                    return span.count * 2
                }
            }
        }
    }
}

private let hexLowercasedDigits: [UInt8] = [
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
    0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66,
]
