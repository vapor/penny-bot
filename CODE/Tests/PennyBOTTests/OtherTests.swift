@testable import PennyBOT
@testable import PennyModels
import XCTest

class OtherTests: XCTestCase {
    
    func testContainsSequence() throws {
        let array = ["a", "bc", "def", "g", "hi"]
        
        XCTAssertTrue(array.containsSequence(["bc"]))
        XCTAssertTrue(array.containsSequence(["bc", "def"]))
        XCTAssertTrue(array.containsSequence(["a"]))
        XCTAssertTrue(array.containsSequence(["a", "bc"]))
        XCTAssertTrue(array.containsSequence(array))
        XCTAssertTrue(array.containsSequence(["hi"]))
        XCTAssertTrue(array.containsSequence(["g", "hi"]))
        XCTAssertTrue(array.containsSequence([]))
        XCTAssertTrue([String]().containsSequence([]))
        
        XCTAssertFalse(array.containsSequence(["g", "h"]))
        XCTAssertFalse(array.containsSequence(["s", "hi"]))
        XCTAssertFalse(array.containsSequence(["a", "def"]))
        
        XCTAssertFalse([].containsSequence(["j"]))
    }
    
    /// The `Codable` logic of `S3AutoPingItems.Expression` is manual, so we
    /// need to make sure it actually works or it might corrupt the repository file.
    func testAutoPingItemExpressionCodable() throws {
        typealias Expression = S3AutoPingItems.Expression
        
        let exp = Expression.text("Hello-world")
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(exp)
        let string = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        
        XCTAssertEqual(string, #""T-Hello-world""#)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Expression.self, from: encoded)
        
        switch decoded {
        case .text("Hello-world"): break
        default:
            XCTFail("\(Expression.self) decoded wrong value: \(decoded)")
        }
    }
}
