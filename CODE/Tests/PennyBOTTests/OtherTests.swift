@testable import PennyBOT
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
        
        XCTAssertFalse(array.containsSequence(["g", "h"]))
        XCTAssertFalse(array.containsSequence(["s", "hi"]))
        XCTAssertFalse(array.containsSequence(["a", "def"]))
        
        XCTAssertFalse([String]().containsSequence([]))
        XCTAssertFalse([].containsSequence(["j"]))
    }
}
