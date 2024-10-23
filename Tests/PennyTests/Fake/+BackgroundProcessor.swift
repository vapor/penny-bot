@testable import Shared

extension BackgroundProcessor {
    nonisolated(unsafe) static var sharedForTests = BackgroundProcessor()
}
