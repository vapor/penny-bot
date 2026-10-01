import NewCodable
import NewCodableFoundation
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@JSONCodable
struct NewCodablePerson: Equatable {
    let name: String
    let age: Int
}

struct CodablePerson: Codable, Equatable {
    let name: String
    let age: Int
}

@JSONCodable
enum NewCodableShape: Equatable {
    case point
    case circle(radius: Double)
}

/// Proves the vendored `NewCodable` targets build, that the macro plugin actually expands, and
/// that the encoders agree with `JSONEncoder` on the wire format.
@Suite
struct NewCodableTests {

    @Test
    func structMatchesJSONEncoder() throws {
        let expected = try JSONEncoder().encode(CodablePerson(name: "Penny", age: 3))
        let actual: Data = try NewJSONEncoder().encode(NewCodablePerson(name: "Penny", age: 3))

        #expect(String(decoding: actual, as: UTF8.self) == String(decoding: expected, as: UTF8.self))
    }

    @Test
    func structRoundTrips() throws {
        let person = NewCodablePerson(name: "Penny", age: 3)
        let encoded: Data = try NewJSONEncoder().encode(person)

        #expect(try NewJSONDecoder().decode(NewCodablePerson.self, from: encoded) == person)
    }

    @Test
    func enumWithAssociatedValueRoundTrips() throws {
        for shape in [NewCodableShape.point, .circle(radius: 1.5)] {
            let encoded: Data = try NewJSONEncoder().encode(shape)

            #expect(try NewJSONDecoder().decode(NewCodableShape.self, from: encoded) == shape)
        }
    }
}
