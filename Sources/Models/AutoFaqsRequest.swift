
public enum AutoFaqsRequest: Codable {
    case all
    case add(expression: String, value: String)
    case remove(expression: String)
}
