import Foundation

struct FileLocations {
    let URLAccounts = "<Path>/penny-bot/CODE/Sources/DBMigration/Data/accounts.txt"
    let URLCoins = "<Path>/penny-bot/CODE/Sources/DBMigration/Data/coins.txt"
    
    func returnFileData(from url: String) -> [String] {
        var lines: [String]
        let path = URL(fileURLWithPath: url)
        let text = try? String(contentsOf: path, encoding: .utf8)
        
        lines = text!.components(separatedBy: "\r\n")
        return lines
    }
}
