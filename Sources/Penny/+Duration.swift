#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Duration {
    var asTimeInterval: TimeInterval {
        let (seconds, attoseconds) = self.components
        return Double(seconds) + (Double(attoseconds) / 1e18)
    }
}
