import Foundation

protocol SOService: Sendable {
    func listQuestions(after: Date) async throws -> [SOQuestions.Item]
}
