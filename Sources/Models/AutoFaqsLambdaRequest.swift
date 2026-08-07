package enum AutoFaqsLambdaRequest: Codable {
    case all
    case add(expression: String, value: String)
    case remove(expression: String)
}
