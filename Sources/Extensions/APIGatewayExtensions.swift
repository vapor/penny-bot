import AWSLambdaEvents
import Crypto
import Foundation

private let jsonDecoder = JSONDecoder()
private let jsonEncoder = JSONEncoder()

extension APIGatewayV2Request {
    
    public func decode<C: Codable>(as type: C.Type = C.self) throws -> C {
        guard let body = self.body,
              let dataBody = body.data(using: .utf8)
        else {
            throw APIError.invalidRequest
        }
        return try jsonDecoder.decode(C.self, from: dataBody)
    }
    
    /// Unused
    public func verifyRequest() throws -> Bool {
        guard let publicKey = ProcessInfo.processInfo.environment["PUBLIC_KEY"]?.hexDecodedData() else {
            fatalError()
        }
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        
        guard let signature = self.headers["x-signature-ed25519"], let timestamp = self.headers["x-signature-timestamp"], let body = self.body else {
            // Throw error to return a 401
            fatalError()
        }
        
        //possibly convert from hex
        let signatureBytes: [UInt8] = .init(signature.hexDecodedData())

        let bodyBytes: [UInt8] = .init("\(timestamp)\(body)".utf8)
        
        return key.isValidSignature(signatureBytes, for: bodyBytes)
    }
}

extension APIGatewayV2Response {
    
    public init(status: HTTPResponseStatus, content: some Encodable) {
        do {
            let data = try jsonEncoder.encode(content)
            let string = String(data: data, encoding: .utf8)
            self.init(statusCode: status, body: string)
        } catch {
            if let data = try? JSONEncoder().encode(content) {
                let string = String(data: data, encoding: .utf8)
                self.init(statusCode: .failedDependency, body: string)
            } else {
                self.init(statusCode: .failedDependency, body: "Plain Error: \(error)")
            }
        }
    }
}

public struct GatewayFailure: Encodable {
    var reason: String
    
    public init(reason: String) {
        self.reason = reason
    }
}

public enum APIError: Error {
    case invalidItem
    case tableNameNotFound
    case invalidRequest
    case invalidHandler
}
