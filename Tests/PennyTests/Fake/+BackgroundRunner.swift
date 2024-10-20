@testable import Shared

extension BackgroundRunner {
    nonisolated(unsafe) static var sharedForTests = BackgroundRunner()
}
