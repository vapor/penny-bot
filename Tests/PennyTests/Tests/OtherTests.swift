import EvolutionMetadataModel
import Markdown
import Testing

@testable import Models
@testable import Penny
@testable import Shared

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
    func removingOccurrencesOfCharacterSetInString() throws {
        let isWhitespace: (Character) -> Bool = { $0.isWhitespace && !$0.isNewline }
        #expect("".removingOccurrences(where: \.isPunctuation) == "")
        #expect("a".removingOccurrences(where: \.isPunctuation) == "a")
        #expect("a,".removingOccurrences(where: \.isPunctuation) == "a")
        #expect(",".removingOccurrences(where: \.isPunctuation) == "")
        #expect(",.?/!{}".removingOccurrences(where: \.isPunctuation) == "")
        #expect("asad,.?/!{d}d".removingOccurrences(where: isWhitespace) == "asad,.?/!{d}d")
        #expect("as , .?/! {d } d".removingOccurrences(where: isWhitespace) == "as,.?/!{d}d")
        #expect("a’b, ".removingOccurrences(where: \.isPunctuation) == "ab ")
    }

    /// Must keep matching `Foundation`'s `addingPercentEncoding(withAllowedCharacters:)`
    /// for `.urlPathAllowed` and `.urlQueryAllowed`.
    @Test
    func percentEncoding() throws {
        #expect("".urlPathEncoded() == "")
        #expect("hello".urlPathEncoded() == "hello")
        #expect("a b".urlPathEncoded() == "a%20b")
        #expect("a/b:c".urlPathEncoded() == "a/b:c")
        #expect("a:b/c".urlPathEncoded() == "a%3Ab/c")
        #expect("~_-.!$&'()*+,;=?@#".urlPathEncoded() == "~_-.!$&'()*+,;=%3F@%23")
        #expect("é🎉".urlPathEncoded() == "%C3%A9%F0%9F%8E%89")
        #expect(
            "https://example.com/a b?x=1&y=2#f".urlPathEncoded()
                == "https%3A//example.com/a%20b%3Fx=1&y=2%23f"
        )

        #expect("".urlQueryEncoded() == "")
        #expect("hello".urlQueryEncoded() == "hello")
        #expect("a b".urlQueryEncoded() == "a%20b")
        #expect("a:b/c".urlQueryEncoded() == "a:b/c")
        #expect("~_-.!$&'()*+,;=?@#".urlQueryEncoded() == "~_-.!$&'()*+,;=?@%23")
        #expect("é🎉".urlQueryEncoded() == "%C3%A9%F0%9F%8E%89")
        #expect(
            "https://example.com/a b?x=1&y=2#f".urlQueryEncoded()
                == "https://example.com/a%20b?x=1&y=2%23f"
        )
    }

    /// Must keep matching `Foundation`'s `trimmingCharacters(in:)` for
    /// `.whitespaces` and `.whitespacesAndNewlines`.
    @Test
    func trimmingWhitespaces() throws {
        #expect("".trimmingWhitespaces() == "")
        #expect("abc".trimmingWhitespaces() == "abc")
        #expect("  a b  ".trimmingWhitespaces() == "a b")
        #expect("   ".trimmingWhitespaces() == "")
        #expect("a\nb".trimmingWhitespaces() == "a\nb")
        /// `.whitespaces` leaves newlines alone, even on the outside.
        #expect("\n a \n".trimmingWhitespaces() == "\n a \n")
        #expect(" \r\n a \r\n ".trimmingWhitespaces() == "\r\n a \r\n")
        /// `U+200B ZERO WIDTH SPACE` is in the set even though it isn't `White_Space`.
        #expect("\u{200B}a\u{200B}".trimmingWhitespaces() == "a")

        #expect("".trimmingWhitespacesAndNewlines() == "")
        #expect("abc".trimmingWhitespacesAndNewlines() == "abc")
        #expect("\n\n".trimmingWhitespacesAndNewlines() == "")
        #expect("a\nb".trimmingWhitespacesAndNewlines() == "a\nb")
        #expect("\n a \n".trimmingWhitespacesAndNewlines() == "a")
        #expect(" \r\n a \r\n ".trimmingWhitespacesAndNewlines() == "a")
        #expect("\u{200B}a\u{200B}".trimmingWhitespacesAndNewlines() == "a")
    }

    /// Must keep matching `Foundation`'s `folding(options: .diacriticInsensitive, locale: nil)`
    /// for the two Latin blocks and for already-decomposed diacritics.
    @Test
    func foldingDiacritics() throws {
        #expect("".foldingDiacritics() == "")
        #expect("abc".foldingDiacritics() == "abc")
        #expect("Ünïcödé".foldingDiacritics() == "Unicode")
        #expect("Ça va?".foldingDiacritics() == "Ca va?")
        #expect("İstanbul".foldingDiacritics() == "Istanbul")
        /// `Ł` has no canonical decomposition, so only `ó` and `ź` fold.
        #expect("Łódź".foldingDiacritics() == "Łodz")
        #expect("Æøß".foldingDiacritics() == "Æøß")
        /// Already-decomposed diacritics are dropped wherever they appear.
        #expect("e\u{0301}".foldingDiacritics() == "e")
        #expect("a\u{0300}\u{0301}b".foldingDiacritics() == "ab")
        #expect("日本".foldingDiacritics() == "日本")
    }

    /// The hash ends up in Discord component ids, so it must not change within a release.
    @Test
    func stableHash() throws {
        #expect("".stableHash == 0)
        #expect("penny".stableHash == 2_749_790_584)
        #expect("hello world".stableHash == 222_957_957)
        #expect("penny".stableHash != "Penny".stableHash)
    }

    /// The `Codable` logic of `S3AutoPingItems.Expression` is manual, so we
    /// need to make sure it actually works or it might corrupt the repository file
    @Test
    func autoPingItemExpressionCodable() throws {
        typealias Expression = S3AutoPingItems.Expression

        do {
            /// Expression.matches
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

        do {
            /// Expression.contains
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
        #expect(
            editedLink.destination
                == "https://github.com/apple/swift-evolution/blob/main/proposals/0400-init-accessors.md"
        )
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
