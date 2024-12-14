@testable import Penny

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct FakeSOService: SOService {

    func listQuestions(after: Date) async throws -> [SOQuestions.Item] {
        TestData.soQuestions
    }
}
