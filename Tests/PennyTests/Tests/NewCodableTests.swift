import Models
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
    let age: Int
    let name: String
}

struct CodablePerson: Codable, Equatable {
    let age: Int
    let name: String
}

@JSONCodable
enum NewCodableShape: Equatable {
    case point
    case circle(radius: Double)
}

struct CodableAutoPingItems: Codable, Equatable {
    struct Expression: RawRepresentable, Codable, Hashable {
        let rawValue: String
    }

    let items: [Expression: Set<UserSnowflake>]
}

/// Proves the vendored `NewCodable` targets build, that the macro plugin actually expands, and
/// that the encoders agree with `JSONEncoder` on the wire format.
@Suite
struct NewCodableTests {

    @Test
    func structMatchesJSONEncoder() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let expected = try encoder.encode(CodablePerson(age: 3, name: "Penny"))
        let actual: Data = try NewJSONEncoder().encode(NewCodablePerson(age: 3, name: "Penny"))

        #expect(String(decoding: actual, as: UTF8.self) == String(decoding: expected, as: UTF8.self))
    }

    @Test
    func structRoundTrips() throws {
        let person = NewCodablePerson(age: 3, name: "Penny")
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

    @Test
    func uuidMatchesJSONEncoder() throws {
        let uuid = UUID()
        let expected = try JSONEncoder().encode(uuid)
        let actual: Data = try NewJSONEncoder().encode(uuid)

        #expect(String(decoding: actual, as: UTF8.self) == String(decoding: expected, as: UTF8.self))
        #expect(try NewJSONDecoder().decode(UUID.self, from: expected) == uuid)
    }

    @Test
    func snowflakeMatchesJSONEncoder() throws {
        let snowflake: UserSnowflake = "1030118727418646629"
        let expected = try JSONEncoder().encode(snowflake)
        let actual: Data = try NewJSONEncoder().encode(snowflake)

        #expect(String(decoding: actual, as: UTF8.self) == String(decoding: expected, as: UTF8.self))
        #expect(try NewJSONDecoder().decode(UserSnowflake.self, from: expected) == snowflake)
    }

    @Test
    func setInteroperatesWithJSONEncoder() throws {
        let snowflakes: Set<UserSnowflake> = ["1030118727418646629", "290483761559240704"]
        let encoded: Data = try NewJSONEncoder().encode(snowflakes)

        #expect(try JSONDecoder().decode(Set<UserSnowflake>.self, from: encoded) == snowflakes)
        #expect(
            try NewJSONDecoder().decode(Set<UserSnowflake>.self, from: JSONEncoder().encode(snowflakes)) == snowflakes
        )
    }

    @Test
    func s3AutoPingItemsKeepsTheRepositoryFormat() throws {
        let repository = #"{"items":["T-penny",["290483761559240704"],"C-vapor",["1030118727418646629"]]}"#
        let items = try NewJSONDecoder().decode(S3AutoPingItems.self, from: Data(repository.utf8))

        #expect(
            items.items == [
                .matches("penny"): ["290483761559240704"],
                .contains("vapor"): ["1030118727418646629"],
            ]
        )

        let encoded: Data = try NewJSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode(CodableAutoPingItems.self, from: encoded)

        #expect(
            decoded.items == [
                .init(rawValue: "T-penny"): ["290483761559240704"],
                .init(rawValue: "C-vapor"): ["1030118727418646629"],
            ]
        )
    }

    @Test
    func dynamoDBUserInteroperatesWithJSONEncoder() throws {
        let user = DynamoDBUser.createNew(forDiscordID: "1030118727418646629")
        let fromCodable = try NewJSONDecoder().decode(DynamoDBUser.self, from: JSONEncoder().encode(user))
        let encoded: Data = try NewJSONEncoder().encode(user)
        let fromNewCodable = try JSONDecoder().decode(DynamoDBUser.self, from: encoded)

        for decoded in [fromCodable, fromNewCodable] {
            #expect(decoded.id == user.id)
            #expect(decoded.discordID == user.discordID)
            #expect(decoded.githubID == user.githubID)
            #expect(decoded.coinCount == user.coinCount)
            #expect(decoded.createdAt == user.createdAt)
        }
    }
}
