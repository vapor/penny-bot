
//MARK: - DereferenceBox
final class DereferenceBox<C: Codable>: Codable {
    var value: C

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(C.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
}
