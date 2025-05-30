import Crypto
/// Import full foundation even on linux for `String(format:_:)`, for now.
package import Foundation

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

extension Sequence where Element == UInt8 {
    /// Returns a hex-encoded `String` buffer from an array of bytes.
    func toHexDigest() -> String {
        self.map { String(format: "%02x", $0) }.joined(separator: "")
    }
}
