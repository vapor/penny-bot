import Foundation

public struct GitHubWebhookPayload: Codable {
    let action: String
    let sponsorship: Sponsorship
    let sender: Sender
    let changes: Changes?

    enum ActionType: String {
        case created
        case cancelled
        case edited
        case tierChanged = "tier_changed"
        case pendingCancellation = "pending_cancellation"
        case pendingTierChange = "pending_tier_change"
    }
}

struct Changes: Codable {
    let tier: ChangesTier
}

struct ChangesTier: Codable {
    let from: FromClass
}

struct FromClass: Codable {
    let nodeID: String
    let createdAt: String
    let tierDescription: String
    let monthlyPriceInCents, monthlyPriceInDollars: Int
    let name: String
    let isOneTime, isCustomAmount: Bool?

    enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case createdAt = "created_at"
        case tierDescription = "description"
        case monthlyPriceInCents = "monthly_price_in_cents"
        case monthlyPriceInDollars = "monthly_price_in_dollars"
        case name
        case isOneTime = "is_one_time"
        case isCustomAmount = "is_custom_amount"
    }
}

struct Sender: Codable {
    let login: String
    let id: Int
    let nodeID: String
    let avatarURL: String
    let gravatarID: String
    let url, htmlURL, followersURL: String
    let followingURL, gistsURL, starredURL: String
    let subscriptionsURL, organizationsURL, reposURL: String
    let eventsURL: String
    let receivedEventsURL: String
    let type: String
    let siteAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case login, id
        case nodeID = "node_id"
        case avatarURL = "avatar_url"
        case gravatarID = "gravatar_id"
        case url
        case htmlURL = "html_url"
        case followersURL = "followers_url"
        case followingURL = "following_url"
        case gistsURL = "gists_url"
        case starredURL = "starred_url"
        case subscriptionsURL = "subscriptions_url"
        case organizationsURL = "organizations_url"
        case reposURL = "repos_url"
        case eventsURL = "events_url"
        case receivedEventsURL = "received_events_url"
        case type
        case siteAdmin = "site_admin"
    }
}

struct Sponsorship: Codable {
    let nodeID: String
    let createdAt: String
    let sponsorable, sponsor: Sender
    let privacyLevel: String
    let tier: Tier

    enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case createdAt = "created_at"
        case sponsorable, sponsor
        case privacyLevel = "privacy_level"
        case tier
    }
}

struct Tier: Codable {
    let nodeID: String
    let createdAt: String
    let tierDescription: String
    let monthlyPriceInCents, monthlyPriceInDollars: Int
    let name: String
    let isOneTime, isCustomAmount: Bool

    enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case createdAt = "created_at"
        case tierDescription = "description"
        case monthlyPriceInCents = "monthly_price_in_cents"
        case monthlyPriceInDollars = "monthly_price_in_dollars"
        case name
        case isOneTime = "is_one_time"
        case isCustomAmount = "is_custom_amount"
    }
}
