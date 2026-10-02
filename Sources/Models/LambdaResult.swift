package import NewCodable

@JSONCodable
package enum LambdaResult<Success: Sendable & JSONCodable>: Sendable {
    case success(Success)
    case failure(reason: String)
}
