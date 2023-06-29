
struct SecurityAndAnalysis: Codable {
    let advancedSecurity: SecurityStatus?
    let secretScanning: SecurityStatus?
    let secretScanningPushProtection: SecurityStatus?

    enum CodingKeys: String, CodingKey {
        case advancedSecurity = "advanced_security"
        case secretScanning = "secret_scanning"
        case secretScanningPushProtection = "secret_scanning_push_protection"
    }

    struct SecurityStatus: Codable {
        let status: Status?

        enum Status: String, Codable {
            case disabled = "disabled"
            case enabled = "enabled"
        }
    }
}
