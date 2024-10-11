#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

protocol SOService: Sendable {
    func listQuestions(after: Date) async throws -> [SOQuestions.Item]
}
