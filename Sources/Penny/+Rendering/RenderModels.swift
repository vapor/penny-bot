
struct AutoPingsContext: Codable {

    struct Commands: Codable {
        let add: String
        let remove: String
        let list: String
        let test: String
    }

    let commands: Commands
    let isTypingEmoji: String
    let defaultExpression: String
}
