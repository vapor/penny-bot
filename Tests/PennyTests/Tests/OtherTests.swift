@testable import Penny
@testable import Models
import Foundation
import EvolutionMetadataModel
import Markdown
import Testing

@Suite
struct OtherTests {
    
    @Test
    func containsSequence() throws {
        let array = ["a", "bc", "def", "g", "hi"]
        
        #expect(array.containsSequence(["bc"]))
        #expect(array.containsSequence(["bc", "def"]))
        #expect(array.containsSequence(["a"]))
        #expect(array.containsSequence(["a", "bc"]))
        #expect(array.containsSequence(array))
        #expect(array.containsSequence(["hi"]))
        #expect(array.containsSequence(["g", "hi"]))
        #expect(array.containsSequence([]))
        #expect([String]().containsSequence([]))
        
        #expect(!array.containsSequence(["g", "h"]))
        #expect(!array.containsSequence(["s", "hi"]))
        #expect(!array.containsSequence(["a", "def"]))
        
        #expect(![].containsSequence(["j"]))
    }
    
    @Test
    func removingOccurrencesCharacterSetInString() throws {
        #expect("".removingOccurrences(of: CharacterSet.punctuationCharacters) == "")
        #expect("a".removingOccurrences(of: CharacterSet.punctuationCharacters) == "a")
        #expect("a,".removingOccurrences(of: CharacterSet.punctuationCharacters) == "a")
        #expect(",".removingOccurrences(of: CharacterSet.punctuationCharacters) == "")
        #expect(",.?/!{}".removingOccurrences(of: CharacterSet.punctuationCharacters) == "")
        #expect("asad,.?/!{d}d".removingOccurrences(of: CharacterSet.whitespaces) == "asad,.?/!{d}d")
        #expect("as , .?/! {d } d".removingOccurrences(of: CharacterSet.whitespaces) == "as,.?/!{d}d")
        #expect("a’b, ".removingOccurrences(of: CharacterSet.punctuationCharacters) == "ab ")
    }
    
    /// The `Codable` logic of `S3AutoPingItems.Expression` is manual, so we
    /// need to make sure it actually works or it might corrupt the repository file
    @Test
    func autoPingItemExpressionCodable() throws {
        typealias Expression = S3AutoPingItems.Expression
        
        do { /// Expression.matches
            let exp = Expression.matches("Hello-world")
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(exp)
            let string = try #require(String(data: encoded, encoding: .utf8))
            
            #expect(string == #""T-Hello-world""#)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Expression.self, from: encoded)
            
            switch decoded {
            case .matches("Hello-world"): break
            default:
                Issue.record("\(Expression.self) decoded wrong value: \(decoded)")
            }
        }
        
        do { /// Expression.contains
            let exp = Expression.contains("Hello-world")
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(exp)
            let string = try #require(String(data: encoded, encoding: .utf8))
            
            #expect(string == #""C-Hello-world""#)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Expression.self, from: encoded)
            
            switch decoded {
            case .contains("Hello-world"): break
            default:
                Issue.record("\(Expression.self) decoded wrong value: \(decoded)")
            }
        }
    }
    
    @Test
    func repairMarkdownLinks() throws {
        let proposal = TestData.proposalContent
        let document = Document(parsing: proposal)
        
        let originalLink = try #require(document.child(through: 1, 0, 0, 1) as? Link)
        #expect(originalLink.destination == "0400-init-accessors.md")
        
        var repairer = LinkRepairer(
            relativeTo: "https://github.com/apple/swift-evolution/blob/main/proposals"
        )
        let newMarkup = repairer.visit(document)
        
        let editedLink = try #require(newMarkup?.child(through: 1, 0, 0, 1) as? Link)
        #expect(editedLink.destination == "https://github.com/apple/swift-evolution/blob/main/proposals/0400-init-accessors.md")
    }
    
    @Test
    func decodeEvolutionProposals() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        _ = try decoder.decode(
            EvolutionMetadata.self,
            from: TestData.newProposalsSample
        )
    }
}
