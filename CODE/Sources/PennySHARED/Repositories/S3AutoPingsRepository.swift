import SotoS3
import Foundation
import PennyModels
import PennyExtensions

struct S3AutoPingsRepository: AutoPingsRepository {
    
    let s3: S3
    let logger: Logger
    let bucket = "penny-auto-pings-lambda"
    let key = "auto-pings-repo.json"
    
    init(awsClient: AWSClient, logger: Logger) {
        self.s3 = S3(client: awsClient, region: .euwest1)
        self.logger = logger
    }
    
    func insert(
        expressions: [S3AutoPingItems.Expression],
        forDiscordID id: String
    ) async throws -> S3AutoPingItems {
        var all = try await self.getAll()
        for expression in expressions {
            all.items[expression, default: []].insert(id)
        }
        try await self.save(items: all)
        return all
    }
    
    func remove(
        expressions: [S3AutoPingItems.Expression],
        forDiscordID id: String
    ) async throws -> S3AutoPingItems {
        var all = try await self.getAll()
        for expression in expressions {
            all.items[expression]?.remove(id)
            if all.items[expression]?.isEmpty == true {
                all.items[expression] = nil
            }
        }
        try await self.save(items: all)
        return all
    }
    
    func getAll() async throws -> S3AutoPingItems {
        let getObjectRequest = S3.GetObjectRequest(bucket: bucket, key: key)
        let response = try await s3.getObject(getObjectRequest, logger: logger)
        if let buffer = response.body?.asByteBuffer(), buffer.readableBytes != 0 {
            do {
                return try JSONDecoder().decode(S3AutoPingItems.self, from: buffer)
            } catch {
                let body = response.body?.asString() ?? "nil"
                logger.error("Cannot find any data in the bucket", metadata: [
                    "response-body": .string(body),
                    "error": "\(error)"
                ])
                return S3AutoPingItems()
            }
        } else {
            let body = response.body?.asString() ?? "nil"
            logger.error("Cannot find any data in the bucket", metadata: [
                "response-body": .string(body)
            ])
            return S3AutoPingItems()
        }
    }
    
    func save(items: S3AutoPingItems) async throws {
        let data = try JSONEncoder().encode(items)
        let putObjectRequest = S3.PutObjectRequest(
            acl: .private,
            body: .data(data),
            bucket: bucket,
            key: key
        )
        _ = try await s3.putObject(putObjectRequest)
    }
}
