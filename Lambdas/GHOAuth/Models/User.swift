import NewCodable

@JSONCodable
struct User {
    let id: Int
    let login: String
}
