enum SponsorType: String {
    case sponsor = "sponsor"
    case backer = "backer"
    
    var roleID: String {
        switch self {
        case .sponsor:
            return "444167329748746262"
        case .backer:
            return "431921695524126722"
        }
    }
    
    var channelID: String {
        switch self {
        case .sponsor:
            return "633345798490292229"
        case .backer:
            return "633345683012976640"
        }
    }
    
    public static func `for`(sponsorshipAmount: Int) throws -> SponsorType {
        switch sponsorshipAmount {
        case 500...9900: return .backer
        case 10000...: return .sponsor
        default:
            throw NoSponsorTypeError()
        }
    }
}

struct NoSponsorTypeError: Error {
    let message = "No SponsorType matching the given sponsorship amount!"
}
