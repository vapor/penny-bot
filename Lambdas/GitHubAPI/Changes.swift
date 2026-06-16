package struct Changes: Sendable, Codable {
    package let new_repository: Repository?
    package let new_issue: Issue?
    package let tier: SponsorshipTierChange?

    package struct SponsorshipTierChange: Sendable, Codable {
        package let from: GHEvent.Sponsorship.Tier
    }
}
