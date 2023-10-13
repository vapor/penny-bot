import Foundation

protocol SOService {
    func listQuestions(after: Date) async throws -> [SOQuestions.Item]
}
