@testable import Penny
import Foundation

struct FakeSOService: SOService {

    func listQuestions(after: Date) async throws -> [SOQuestions.Item] {
        TestData.soQuestions
    }
}
