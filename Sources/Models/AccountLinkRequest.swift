#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

package struct AccountLinkRequest: Codable {
    let id: UUID
    let createdAt: Date
    let initiationSource: String
    let initiationId: String
    let requestedSource: String
    let requestedId: String
    let reference: String
}
