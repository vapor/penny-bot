package import NewCodable

@JSONCodable
package enum AutoFaqsLambdaRequest {
    case all
    case add(expression: String, value: String)
    case remove(expression: String)
}
