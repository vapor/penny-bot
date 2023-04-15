
public enum HelpsRequest: Codable {
    case all
    case add(name: String, value: String)
    case remove(name: String)
}
