
struct Permissions: Codable {
    let admin, maintain, pull, push: Bool?
    let triage: Bool?
}
