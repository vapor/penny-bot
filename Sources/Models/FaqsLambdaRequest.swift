package import NewCodable

@JSONCodable
package enum FaqsLambdaRequest {
    case all
    case add(name: String, value: String)
    case remove(name: String)
}
